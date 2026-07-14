class Integration < ApplicationRecord
  include ConfigSecretFiltering

  belongs_to :account
  belongs_to :environment, optional: true

  # Social integrations (Meta) are linked to regions through social_channels.
  has_many :social_channels, dependent: :destroy

  after_initialize { self.config = {} if config.is_a?(Array) }

  # STI subclasses a client is allowed to instantiate. Prevents a client from
  # setting `type` to an arbitrary class via mass assignment.
  PERMITTED_TYPES = %w[
    SesIntegration SmtpIntegration TwilioIntegration WhatsappIntegration
    FcmIntegration ApnsIntegration WebPushIntegration MetaSocialIntegration
    LinkedinSocialIntegration
  ].freeze

  validates :type, inclusion: { in: PERMITTED_TYPES }, allow_nil: true
  validate :environment_belongs_to_account

  # Non-email kinds: one per environment. Email and mobile_push allow multiple
  # (email: notification vs campaign; mobile_push: FCM + APNs can coexist). Social
  # is also exempt — a region links many social accounts (multiple pages/markets).
  validates :kind, uniqueness: {
    scope: [:account_id, :environment_id],
    message: "already has an integration configured for this environment"
  }, unless: -> { email? || mobile_push? || social? }

  scope :email, -> { where(kind: 'email') }
  scope :sms, -> { where(kind: 'sms') }
  scope :whatsapp, -> { where(kind: 'whatsapp') }
  scope :mobile_push, -> { where(kind: 'mobile_push') }
  scope :web_push, -> { where(kind: 'web_push') }
  scope :social, -> { where(kind: 'social') }

  enum :kind, { email: 0, sms: 1, whatsapp: 2, mobile_push: 3, web_push: 4, social: 5 }

  after_create :auto_assign_email_preference
  before_destroy :clear_email_preferences

  # Extract trigger data from message tags and merge with message_id.
  # FCM requires all data values to be strings.
  def push_data(message)
    base = { message_id: message.id.to_s }
    trigger_data = message.tags&.find { |t| t.is_a?(Hash) && t.key?("trigger_data") }
    if trigger_data
      trigger_data["trigger_data"].each do |k, v|
        base[k.to_sym] = v.to_s
      end
    end
    base
  end

  private

  # An integration may only be attached to an environment owned by the same
  # account — otherwise a client could mass-assign a foreign environment_id.
  def environment_belongs_to_account
    return if environment_id.blank?
    if environment&.account_id != account_id
      errors.add(:environment, "must belong to the same account")
    end
  end

  def auto_assign_email_preference
    return unless email? && environment.present?

    env = environment
    if env.notification_email_integration_id.nil?
      env.update_column(:notification_email_integration_id, id)
    end
    if env.campaign_email_integration_id.nil?
      env.update_column(:campaign_email_integration_id, id)
    end
  end

  def clear_email_preferences
    return unless email? && environment.present?

    env = environment
    env.update_column(:notification_email_integration_id, nil) if env.notification_email_integration_id == id
    env.update_column(:campaign_email_integration_id, nil) if env.campaign_email_integration_id == id
  end
end
