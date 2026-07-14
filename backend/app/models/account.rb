class Account < ApplicationRecord
  # Billing plans. Paid plans map to a Stripe Price via env vars (set with the
  # test/live keys). `free` is the open-source / self-host plan (no subscription).
  PLANS = {
    "free"    => { name: "Open source",    amount: 0,    price_env: nil,                   coming_soon: false },
    "byok"    => { name: "Cloud · BYOK",    amount: 2000, price_env: "STRIPE_PRICE_BYOK",    coming_soon: false },
    "managed" => { name: "Cloud · Managed", amount: 6000, price_env: "STRIPE_PRICE_MANAGED", coming_soon: false },
  }.freeze

  PAID_PLANS = %w[byok managed].freeze

  def self.price_id_for(plan)
    env = PLANS.dig(plan, :price_env)
    env && ENV[env].presence
  end

  def self.plan_for_price(price_id)
    return nil if price_id.blank?
    PLANS.keys.find { |k| price_id_for(k) == price_id }
  end

  def paid_plan?
    PAID_PLANS.include?(plan)
  end

  def plan_display_name
    PLANS.dig(plan, :name) || plan.to_s.titleize
  end

  # Destroy order matters: FK constraints require children before parents.
  # conversation_messages → conversations → {environments, customers, users}
  # campaign_deliveries → campaigns → {segments, templates, environments, customers}
  has_many :conversation_messages, dependent: :destroy
  has_many :conversations, dependent: :destroy
  has_many :conversation_tags, dependent: :destroy
  has_many :canned_responses, dependent: :destroy
  has_many :mailboxes, dependent: :destroy
  has_many :email_threads, dependent: :destroy
  has_many :operator_profiles, dependent: :destroy
  has_one :chat_widget_settings, dependent: :destroy
  has_many :campaign_deliveries, dependent: :destroy
  has_many :campaigns, dependent: :destroy
  has_many :social_regions, dependent: :destroy
  has_many :social_post_deliveries, dependent: :destroy
  # Drip children before segments/customers: drip_campaigns belong_to a segment,
  # and enrollments/memberships reference customers (FK destroy order).
  has_many :drip_step_executions, dependent: :destroy
  has_many :drip_enrollments, dependent: :destroy
  has_many :drip_steps, dependent: :destroy
  has_many :drip_campaigns, dependent: :destroy
  has_many :segment_memberships, dependent: :destroy
  has_many :segments, dependent: :destroy
  has_many :sending_identities, dependent: :destroy

  def default_sending_identity
    sending_identities.find_by(is_default: true)
  end
  has_many :opens, dependent: :destroy
  has_many :deliveries, dependent: :destroy
  has_many :customer_activities, dependent: :destroy
  has_many :messages, dependent: :destroy
  has_many :rules, dependent: :destroy
  has_many :templates, dependent: :destroy
  has_many :folders, dependent: :destroy
  has_many :integrations, dependent: :destroy
  has_many :device_tokens, dependent: :destroy
  has_many :csv_imports, dependent: :destroy
  has_many :customers, dependent: :destroy
  has_many :environments, dependent: :destroy
  has_many :users, dependent: :destroy
  has_one :mcp_setting, dependent: :destroy
  has_many :mcp_grants, dependent: :destroy
  has_many :mcp_request_logs, dependent: :destroy

  # MCP master switch. False until an admin enables it (no row = off).
  def mcp_enabled?
    mcp_setting&.enabled? || false
  end

  validates :name, presence: true
  validates :plan, presence: true
  validates :status, inclusion: { in: %w[pending_verification active suspended] }
  attribute :message_retention_days, :integer, default: 180
  validates :message_retention_days, inclusion: { in: [ 30, 60, 90, 180 ] }

  scope :trial_accounts,   -> { where(plan: 'trial') }
  scope :paid_accounts,    -> { where.not(plan: 'trial') }
  scope :pending,          -> { where(status: 'pending_verification') }
  scope :active_accounts,  -> { where(status: 'active') }

  FREE_MESSAGE_LIMIT = 10_000

  # ── Plan helpers ─────────────────────────────────────────────────────────────

  def trial?
    plan == 'trial'
  end

  def free?
    plan.in?(%w[free trial])
  end

  def pro?
    plan == 'pro'
  end

  def trial_expired?
    trial? && trial_ends_at && trial_ends_at < Time.current
  end

  # ── Status helpers ───────────────────────────────────────────────────────────

  def pending_verification?
    status == 'pending_verification'
  end

  def active?
    status == 'active'
  end

  def suspended?
    status == 'suspended'
  end

  # ── Onboarding ───────────────────────────────────────────────────────────────

  def onboarding_completed?
    onboarding_completed_at.present?
  end

  # ── Plan limits ──────────────────────────────────────────────────────────────

  def allows_channel?(channel)
    return true if pro?
    channel.to_s == 'email'
  end

  def monthly_message_count
    messages.where('created_at >= ?', Time.current.beginning_of_month).count
  end

  def message_limit_reached?
    free? && monthly_message_count >= FREE_MESSAGE_LIMIT
  end

  def message_limit
    free? ? FREE_MESSAGE_LIMIT : nil
  end

  # ── Ticket numbers ──────────────────────────────────────────────────────────

  def next_ticket_number!
    result = self.class.connection.select_value(
      "UPDATE accounts SET next_ticket_number = next_ticket_number + 1 WHERE id = #{id} RETURNING next_ticket_number - 1"
    )
    "##{result}"
  end

  # ── Tracking domain ─────────────────────────────────────────────────────────

  def tracking_base_url
    if tracking_domain.present?
      "https://#{tracking_domain}"
    else
      ENV.fetch('API_URL', 'http://localhost:3300')
    end
  end
end
