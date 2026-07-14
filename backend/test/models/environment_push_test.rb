require "test_helper"

class EnvironmentPushTest < ActiveSupport::TestCase
  test "resolve_push_integrations returns both fcm and apns" do
    env = environments(:production)
    result = env.resolve_push_integrations
    assert_equal integrations(:fcm), result[:fcm]
    assert_equal integrations(:apns), result[:apns]
  end

  test "resolve_push_integrations omits missing integrations" do
    integrations(:apns).update!(active: false)
    env = environments(:production)

    result = env.resolve_push_integrations
    assert_equal integrations(:fcm), result[:fcm]
    assert_nil result[:apns]

    integrations(:apns).update!(active: true)
  end

  test "resolve_push_integrations falls back to account-level" do
    env = environments(:staging)
    # Staging has no integrations, create account-level FCM
    account_fcm = FcmIntegration.create!(
      account: accounts(:acme), environment: nil, vendor: "fcm",
      config: { "project_id" => "account-level" }
    )

    result = env.resolve_push_integrations
    assert_equal account_fcm, result[:fcm]

    account_fcm.destroy!
  end

  test "resolve_push_integrations returns empty when none configured" do
    env = environments(:staging)
    result = env.resolve_push_integrations
    assert_empty result
  end

  test "global_channel_allowed? returns allow_mobile_push for push channel" do
    env = environments(:production)
    assert env.send(:global_channel_allowed?, "push")
  end

  test "global_channel_allowed? returns allow_web_push for web_push channel" do
    env = environments(:production)
    assert env.send(:global_channel_allowed?, "web_push")
  end

  test "message_channel returns push for MobilePushMessage" do
    env = environments(:production)
    msg = MobilePushMessage.new
    assert_equal "push", env.send(:message_channel, msg)
  end

  test "message_channel returns web_push for WebPushMessage" do
    env = environments(:production)
    msg = WebPushMessage.new
    assert_equal "web_push", env.send(:message_channel, msg)
  end
end
