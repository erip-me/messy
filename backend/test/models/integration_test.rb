require "test_helper"

class IntegrationTest < ActiveSupport::TestCase
  fixtures :all

  test "kind enum values" do
    ses = integrations(:ses)
    assert ses.email?

    twilio = integrations(:twilio)
    assert twilio.sms?
  end

  test "email scope returns email integrations" do
    email_integrations = Integration.email
    assert_includes email_integrations, integrations(:ses)
    assert_not_includes email_integrations, integrations(:twilio)
  end

  test "sms scope returns sms integrations" do
    sms_integrations = Integration.sms
    assert_includes sms_integrations, integrations(:twilio)
    assert_not_includes sms_integrations, integrations(:ses)
  end

  test "whatsapp scope returns whatsapp integrations" do
    whatsapp_integrations = Integration.whatsapp
    assert_includes whatsapp_integrations, integrations(:whatsapp)
    assert_not_includes whatsapp_integrations, integrations(:ses)
  end

  test "mobile_push scope returns mobile_push integrations" do
    mobile_push_integrations = Integration.mobile_push
    assert_includes mobile_push_integrations, integrations(:fcm)
    assert_not_includes mobile_push_integrations, integrations(:ses)
  end

  test "web_push scope returns web_push integrations" do
    web_push_integrations = Integration.web_push
    assert_not_includes web_push_integrations, integrations(:ses)
  end

  test "allows multiple email integrations per environment" do
    existing = integrations(:ses)
    smtp = Integration.new(
      account: existing.account,
      environment: existing.environment,
      kind: :email,
      type: "SmtpIntegration",
      vendor: "smtp",
      config: {}
    )
    assert smtp.valid?, smtp.errors.full_messages.join(", ")
  end

  test "prevents duplicate non-email kind per environment" do
    existing = integrations(:twilio)
    duplicate = Integration.new(
      account: existing.account,
      environment: existing.environment,
      kind: :sms,
      type: "TwilioIntegration",
      vendor: "twilio",
      config: {}
    )
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:kind], "already has an integration configured for this environment"
  end

  test "allows same kind on different environments" do
    ses = integrations(:ses)
    other_env_ses = Integration.new(
      account: ses.account,
      environment: environments(:staging),
      kind: :email,
      type: "SmtpIntegration",
      vendor: "smtp",
      config: {}
    )
    assert other_env_ses.valid?
  end

  test "auto-assigns notification preference on first email integration create" do
    env = environments(:staging)
    # Ensure no email integrations exist in staging
    env.integrations.email.destroy_all
    env.update_columns(notification_email_integration_id: nil, campaign_email_integration_id: nil)

    smtp = Integration.create!(
      account: accounts(:acme),
      environment: env,
      kind: :email,
      type: "SmtpIntegration",
      vendor: "smtp",
      config: {}
    )

    env.reload
    assert_equal smtp.id, env.notification_email_integration_id
    assert_equal smtp.id, env.campaign_email_integration_id

    smtp.destroy
  end

  test "does not overwrite existing preference on second email integration create" do
    env = environments(:production)
    original_notif = env.notification_email_integration_id || integrations(:ses).id
    env.update_columns(
      notification_email_integration_id: integrations(:ses).id,
      campaign_email_integration_id: integrations(:ses).id
    )

    smtp = Integration.create!(
      account: accounts(:acme),
      environment: env,
      kind: :email,
      type: "SmtpIntegration",
      vendor: "smtp",
      config: {}
    )

    env.reload
    assert_equal integrations(:ses).id, env.notification_email_integration_id
    assert_equal integrations(:ses).id, env.campaign_email_integration_id

    smtp.destroy
  end

  test "clears preferences when email integration is destroyed" do
    env = environments(:production)
    smtp = Integration.create!(
      account: accounts(:acme),
      environment: env,
      kind: :email,
      type: "SmtpIntegration",
      vendor: "smtp",
      config: {}
    )
    env.update_columns(campaign_email_integration_id: smtp.id)

    smtp.destroy
    env.reload
    assert_nil env.campaign_email_integration_id
  end

  test "config defaults to hash not array" do
    i = Integration.new
    assert_kind_of Hash, i.config
  end

  test "push_data returns message_id when no tags" do
    message = MobilePushMessage.create!(
      account: accounts(:acme),
      environment: environments(:production),
      to: "test@example.com",
      body: "Test",
      status: :pending
    )
    result = integrations(:fcm).push_data(message)
    assert_equal({ message_id: message.id.to_s }, result)
  end

  test "push_data includes trigger_data from tags" do
    message = MobilePushMessage.create!(
      account: accounts(:acme),
      environment: environments(:production),
      to: "test@example.com",
      body: "Test",
      status: :pending,
      tags: [{ "trigger_data" => { "type" => "rfq_assigned", "key" => "abc12345" } }]
    )
    result = integrations(:fcm).push_data(message)
    assert_equal message.id.to_s, result[:message_id]
    assert_equal "rfq_assigned", result[:type]
    assert_equal "abc12345", result[:key]
  end

  test "push_data converts all values to strings for FCM compatibility" do
    message = MobilePushMessage.create!(
      account: accounts(:acme),
      environment: environments(:production),
      to: "test@example.com",
      body: "Test",
      status: :pending,
      tags: [{ "trigger_data" => { "type" => "order_update", "key" => "def67890", "amount" => 500 } }]
    )
    result = integrations(:fcm).push_data(message)
    assert_equal "500", result[:amount]
    assert result.values.all? { |v| v.is_a?(String) }
  end

  test "push_data handles empty tags" do
    message = MobilePushMessage.create!(
      account: accounts(:acme),
      environment: environments(:production),
      to: "test@example.com",
      body: "Test",
      status: :pending,
      tags: []
    )
    result = integrations(:fcm).push_data(message)
    assert_equal({ message_id: message.id.to_s }, result)
  end

  # --- Cross-account / mass-assignment guards (security) ---

  test "rejects an environment owned by another account" do
    integration = SmtpIntegration.new(
      account: accounts(:acme),
      environment: environments(:other_env), # belongs to other_co
      vendor: "smtp"
    )
    assert_not integration.valid?
    assert_includes integration.errors[:environment], "must belong to the same account"
  end

  test "accepts an environment owned by the same account" do
    integration = SmtpIntegration.new(
      account: accounts(:acme),
      environment: environments(:staging),
      vendor: "smtp"
    )
    assert integration.valid?, integration.errors.full_messages.to_sentence
  end

end
