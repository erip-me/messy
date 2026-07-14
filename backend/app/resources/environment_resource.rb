class EnvironmentResource
  include Alba::Resource

  attributes :id, :account_id, :name, :tag, :api_key, :is_deleted,
             :allow_email, :allow_sms, :allow_whatsapp, :allow_mobile_push,
             :allow_web_push, :whatsapp_phone_id,
             :campaign_email_integration_id, :notification_email_integration_id,
             :created_at, :updated_at

  # Masked sentinel, never the credential itself (see ConfigSecretFiltering).
  attribute :whatsapp_token do |env|
    env.whatsapp_token.present? ? ConfigSecretFiltering::FILTERED : env.whatsapp_token
  end
end
