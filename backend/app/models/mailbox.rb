class Mailbox < ApplicationRecord
  belongs_to :account
  belongs_to :environment

  has_many :email_threads, dependent: :destroy

  enum :provider, { imap: 0, gmail: 1, office365: 2 }

  validates :name, presence: true
  validates :email_address, presence: true, uniqueness: { scope: :account_id }
  validates :provider, presence: true

  scope :active_mailboxes, -> { where(active: true) }
  # Providers that authenticate through OAuth (vs. IMAP username/password).
  scope :oauth_mailboxes, -> { where(provider: [providers[:gmail], providers[:office365]]) }

  def next_ticket_number!
    prefix = ticket_prefix.present? ? "#{ticket_prefix}-" : "#"
    # Atomic increment + return in a single query to prevent race conditions
    result = self.class.connection.uncached do
      self.class.connection.select_value(
        "UPDATE mailboxes SET next_ticket_number = next_ticket_number + 1 WHERE id = #{id} RETURNING next_ticket_number"
      )
    end
    "#{prefix}#{result}"
  end

  def from_address(integration = nil)
    if integration.respond_to?(:source) && integration.source.present?
      integration.source
    else
      email_address
    end
  end

  def notification_enabled?(event)
    notification_events&.dig(event.to_s) == true
  end

  # ── Ingestion + OAuth/push wiring ──────────────────────────────────────────

  def oauth?
    gmail? || office365?
  end

  # The fetcher used for polling (and for a push-triggered catch-up fetch).
  def fetcher
    case provider
    when "imap"      then EmailIngestion::ImapFetcher.new(self)
    when "gmail"     then EmailIngestion::GmailFetcher.new(self)
    when "office365" then EmailIngestion::Office365Fetcher.new(self)
    end
  end

  # The push manager (Gmail watch / Graph subscription), or nil for IMAP.
  def push_service
    case provider
    when "gmail"     then EmailIngestion::GmailPush.new(self)
    when "office365" then EmailIngestion::GraphPush.new(self)
    end
  end

  # OAuth providers are "connected" once we hold a refresh token. IMAP is always
  # considered connected (its credentials live in config from creation).
  def connected?
    return config["password"].present? if imap?
    config["refresh_token"].present?
  end

  # Has a push channel ever been established (may be expired and due for renewal)?
  def push_registered?
    sync_state["watch_expiration"].present? || sync_state["subscription_id"].present?
  end

  # Is a live push channel (Gmail watch / Graph subscription) currently in force?
  def push_active?
    case provider
    when "gmail"
      exp = sync_state["watch_expiration"].to_i        # ms epoch
      exp.positive? && exp > (Time.current.to_f * 1000)
    when "office365"
      exp = sync_state["subscription_expires_at"]
      exp.present? && Time.parse(exp) > Time.current
    else
      false
    end
  rescue ArgumentError, TypeError
    false
  end
end
