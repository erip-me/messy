class Environment < ApplicationRecord
  belongs_to :account
  belongs_to :notification_email_integration, class_name: 'Integration', optional: true
  belongs_to :campaign_email_integration, class_name: 'Integration', optional: true
  has_many :rules, dependent: :destroy
  has_many :integrations, dependent: :destroy
  has_many :templates, dependent: :destroy
  has_many :messages, dependent: :destroy
  has_many :folders, dependent: :destroy
  has_many :layouts, dependent: :destroy

  scope :active, -> { where(is_deleted: false) }

  validates :name, presence: true

  # whatsapp_token is a third-party (Meta) access token with no in-app display
  # need, so mask it on serialization. api_key is the tenant's own credential,
  # surfaced for the "copy API key" UI, so it stays visible to its owner.
  def as_json(options = {})
    json = super
    json["whatsapp_token"] = ConfigSecretFiltering::FILTERED if json.key?("whatsapp_token") && whatsapp_token.present?
    json
  end
  validate :integration_preferences_belong_to_environment
  before_validation :auto_fill_email_preferences, on: :update

  # Resolves the correct integration for a given kind and purpose.
  # purpose: :notification (system/transactional) or :campaign
  def resolve_integration(kind, purpose: :notification)
    kind = kind.to_sym

    if kind == :email
      preferred = if purpose == :campaign
                    campaign_email_integration || notification_email_integration
                  else
                    notification_email_integration
                  end
      return preferred if preferred&.active?
    end

    # Fallback: first active integration of this kind in the environment, then account-level
    integrations.where(kind: kind, active: true).first ||
      account.integrations.where(kind: kind, environment_id: nil, active: true).first
  end

  before_validation(on: :create) do
    if self.api_key.blank?
      # Make sure to create the api key for new records
      self.api_key = SecureRandom.hex(20) + "=="
    end
  end

  # Checks if the rule for the given message and recipient passes
  def check_rules?(message, rcpt)
    check_rules_for_channel?(message_channel(message), rcpt)[:result]
  end

  # Channel-based rule check (usable without a Message object)
  # Returns { result: :passed/:failed, reason: string|nil }
  # Pass preloaded_rules to avoid a query per call in batch contexts.
  def check_rules_for_channel?(channel, rcpt, preloaded_rules: nil)
    # Only rules for this channel apply. Without the type filter an SmsRule's
    # condition would also block an email to the same domain.
    rule_type = Rule::TYPE_MAP[channel.to_s]

    scoped_rules = if preloaded_rules
                     preloaded_rules.select { |r| r.type == rule_type }
                   else
                     rules.where(active: true, type: rule_type)
                   end

    scoped_rules.each do |rule|
      case rule.passes?(nil, rcpt)
      when :allow
        return { result: :passed, reason: nil }
      when :deny
        return { result: :failed, reason: "Blocked by rule: #{rule.condition}" }
      end
    end

    if global_channel_allowed?(channel)
      { result: :passed, reason: nil }
    else
      { result: :failed, reason: "#{channel.capitalize} channel is set to block by default" }
    end
  end

  # Returns all active push integrations for multi-integration delivery.
  # FCM handles Android (+ iOS if no APNs), APNs handles iOS directly.
  def resolve_push_integrations
    fcm = integrations.where(type: FcmIntegration.name, active: true).first ||
          account.integrations.where(type: FcmIntegration.name, environment_id: nil, active: true).first
    apns = integrations.where(type: ApnsIntegration.name, active: true).first ||
           account.integrations.where(type: ApnsIntegration.name, environment_id: nil, active: true).first
    { fcm: fcm, apns: apns }.compact
  end

  private
    def message_channel(message)
      case message
      when EmailMessage then 'email'
      when SmsMessage then 'sms'
      when WhatsappMessage then 'whatsapp'
      when MobilePushMessage then 'push'
      when WebPushMessage then 'web_push'
      end
    end

    def global_channel_allowed?(channel)
      case channel.to_s
      when 'email' then allow_email
      when 'sms' then allow_sms
      when 'whatsapp' then allow_whatsapp
      when 'push' then allow_mobile_push
      when 'web_push' then allow_web_push
      end
    end

    def auto_fill_email_preferences
      return if notification_email_integration_id.present? && campaign_email_integration_id.present?

      default_email = available_email_integrations.find_by(active: true)
      return unless default_email

      self.notification_email_integration_id ||= default_email.id
      self.campaign_email_integration_id ||= default_email.id
    end

    def available_email_integrations
      account.integrations.where(kind: :email).where(environment_id: [id, nil])
    end

    def integration_preferences_belong_to_environment
      if notification_email_integration_id.present?
        int = Integration.find_by(id: notification_email_integration_id)
        unless int && int.email? && (int.environment_id == id || (int.environment_id.nil? && int.account_id == account_id))
          errors.add(:notification_email_integration, 'must be an email integration available to this environment')
        end
      end

      if campaign_email_integration_id.present?
        int = Integration.find_by(id: campaign_email_integration_id)
        unless int && int.email? && (int.environment_id == id || (int.environment_id.nil? && int.account_id == account_id))
          errors.add(:campaign_email_integration, 'must be an email integration available to this environment')
        end
      end
    end
end
