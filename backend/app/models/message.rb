class Message < ApplicationRecord
  include TrackingLinkSigner

  # Namespaces transactional click signatures, keeping them distinct from
  # campaign links (CampaignLinkSigner::SIGNATURE_PURPOSE).
  CLICK_SIGNATURE_PURPOSE = "message_click".freeze

  # Emails carrying one-time credentials or secret-token links (magic links,
  # OTPs, password resets, email verification, security codes). We never wrap
  # their links in a click-tracking redirect — that would route the secret
  # through the tracking domain (extra hop + logged in its access logs).
  #
  # Matched against BOTH the trigger and the subject, because callers (e.g.
  # Lalaaji) often send transactional mail with trigger: nil and the sensitive
  # nature only shows in the subject ("Your Lalaaji OTP: 1234"). `_`, `.`, `-`,
  # spaces and digits act as word boundaries; the leading lookbehind avoids
  # mid-word hits (e.g. "preset" won't match "reset"). Order confirmations,
  # reminders, RFQ/bid notifications, etc. are NOT matched.
  SECURITY_SENSITIVE_PATTERN = /(?<![a-z])(?:otp|magic|2fa|mfa|passwords?|passcode|verif\w*|one.?time|sign.?in|log.?in|activate|reset|security|confirm.?email|email.?confirm)/i

  has_many_attached :attachments
  has_many :deliveries
  has_many :opens
  has_many :clicks
  has_many :child_messages, class_name: 'Message', foreign_key: :parent_message_id

  belongs_to :account
  belongs_to :environment
  belongs_to :template, optional: true
  belongs_to :parent_message, class_name: 'Message', optional: true
  belongs_to :drip_campaign, optional: true
  belongs_to :sending_identity, optional: true
  belongs_to :drip_step, optional: true

  # A caller can pass any sending_identity_id; make sure it's one of this
  # account's identities so account A can't send using account B's From line.
  validate :sending_identity_belongs_to_account, if: :sending_identity_id

  enum :scope, {
    any: 0,
    internal: 1,
    external: 2
  }

  enum :status, {
    pending: 0,
    draft: 1,
    sent: 10,
    delivered: 15,
    expired: 20,
    failed: 30,
    rejected: 40,
    suppressed: 45
  }

  def tag
    environment.tag
  end

  def tagged_subject
    tag.blank? ? subject : "[#{tag}] #{subject}"
  end

  def tagged_body
    tag.blank? ? body : "[#{tag}] #{body}"
  end

  def self.build_from(message_params, template = nil)
    message = self.new(message_params)

    if template
      message.template = template
      message.subject = template.subject
      message.body = template.body
    end

    message
  end

  # Broadcast changes to live activity feed
  after_create_commit  :broadcast_create
  after_update_commit  :broadcast_update

  # Auto-create customers for recipients
  after_create_commit :ensure_customers_for_recipients

  # Tracking functionality
  before_create :generate_tracking_credentials

  def generate_tracking_token
    return if tracking_salt.present? && tracking_token.present?
    
    self.tracking_salt = SecureRandom.hex(32)
    self.tracking_token = Digest::SHA256.hexdigest("#{id || SecureRandom.uuid}#{tracking_salt}")
  end

  def tracking_pixel_url
    return nil unless tracking_token.present?
    "#{account.tracking_base_url}/track/#{tracking_token}.png"
  end

  def inject_tracking_pixel
    return body unless tracking_token.present?

    pixel_url = tracking_pixel_url
    return body unless pixel_url
    
    pixel_tag = %(<img src="#{pixel_url}" width="1" height="1" style="display:none" />)
    
    # Insert before closing body tag if present, otherwise append
    if body.include?('</body>')
      body.sub('</body>', "#{pixel_tag}</body>")
    else
      "#{body}#{pixel_tag}"
    end
  end

  # Full HTML for an outbound email: links rewritten to signed click-tracking
  # redirects, plus the open pixel. Mirrors the campaign send path so transactional
  # mail gets the same open + click tracking. Integrations call this for the HTML
  # part (the text part stays untracked).
  def tracked_html
    rewrite_tracking_links(inject_tracking_pixel)
  end

  def opened?
    opens.any?
  end

  def last_opened_at
    opens.maximum(:opened_at)
  end

  def clicked?
    clicks.any?
  end

  def last_clicked_at
    clicks.maximum(:clicked_at)
  end

  # Emails carrying one-time credential links (magic link, OTP, password reset)
  # are excluded from click-link rewriting so the secret token never passes
  # through the tracking domain. Checks trigger AND subject (callers often send
  # with a nil trigger, e.g. "Your Lalaaji OTP: 1234").
  def security_sensitive?
    [trigger, subject].any? { |v| v.present? && v.match?(SECURITY_SENSITIVE_PATTERN) }
  end

  # Per-link click counts for this message: { url => count }, most-clicked first.
  def link_click_counts
    clicks.group(:url).count.sort_by { |_url, count| -count }.to_h
  end

  # tracking_salt is the per-message HMAC salt used to mint tracking tokens;
  # it must never be serialized (it would let a client forge tracking links).
  def as_json(options = {})
    super(options).except("tracking_salt")
  end

  private

  # Wrap each <a href> in a signed click-tracking redirect through the account's
  # tracking domain. Skips non-http links (mailto:, tel:, #anchors) and links that
  # already point at the tracking host (our own pixel/unsubscribe/redirect URLs),
  # so we never double-wrap or rewrite the unsubscribe link.
  def rewrite_tracking_links(html)
    return html unless tracking_token.present? && html.present?
    return html if security_sensitive?

    base = account.tracking_base_url
    TrackingLinkRewriter.call(
      html,
      base: base,
      token: tracking_token,
      path: "track",
      sign: ->(url) { tracking_link_signature(url, CLICK_SIGNATURE_PURPOSE) },
      skip: ->(url) { !trackable_link?(url, base) }
    )
  end

  def sending_identity_belongs_to_account
    errors.add(:sending_identity, 'must belong to the same account') if sending_identity && sending_identity.account_id != account_id
  end

  def trackable_link?(url, tracking_base)
    return false unless url.match?(%r{\Ahttps?://}i)
    !url.start_with?(tracking_base)
  end

  def generate_tracking_credentials
    generate_tracking_token
  end

  def broadcast_payload
    {
      message: as_json.merge(
        channel: type&.sub('Message', '')&.downcase,
        environment: environment&.name
      )
    }
  end

  def broadcast_create
    ActionCable.server.broadcast "messages_channel_#{account_id}", broadcast_payload.merge(action: "create")
  end

  def broadcast_update
    ActionCable.server.broadcast "messages_channel_#{account_id}", broadcast_payload.merge(action: "update")
  end

  def ensure_customers_for_recipients
    return if parent_message_id.present? # skip child messages, parent already handled it

    [self.to, self.cc, self.bcc].compact_blank.each do |field|
      Mail::AddressList.new(field).addresses.each do |addr|
        next unless addr.address.present?
        customer = account.customers.find_or_initialize_by(email: addr.address.downcase)
        if customer.new_record?
          customer.first_name = addr.display_name&.split(' ')&.first
          customer.last_name = addr.display_name&.split(' ', 2)&.last if addr.display_name&.include?(' ')
        end
        was_new = customer.new_record?
        customer.last_seen_at = Time.current if was_new
        customer.save!
        customer.touch_last_seen unless was_new
      rescue ActiveRecord::RecordInvalid
        # skip invalid emails silently
      end
    end
  rescue StandardError => e
    Rails.logger.warn "Failed to ensure customers for message #{id}: #{e.message}"
  end
end
