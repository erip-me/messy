require "test_helper"

class PushIntegrationUniquenessTest < ActiveSupport::TestCase
  test "allows FCM and APNs to coexist in the same environment" do
    # Both fcm and apns fixtures are kind: mobile_push, same environment
    assert integrations(:fcm).valid?
    assert integrations(:apns).valid?
  end

  test "allows creating second mobile_push integration in same environment" do
    new_apns = ApnsIntegration.new(
      account: accounts(:acme),
      environment: environments(:production),
      vendor: "apns",
      config: { "team_id" => "NEW", "key_id" => "NEW", "private_key" => "x", "bundle_id" => "com.new.app" }
    )
    # This would fail if uniqueness wasn't relaxed for mobile_push
    assert new_apns.valid?, new_apns.errors.full_messages.join(", ")
  end

  test "still prevents duplicate sms kind per environment" do
    duplicate = TwilioIntegration.new(
      account: accounts(:acme),
      environment: environments(:production),
      vendor: "twilio",
      config: {}
    )
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:kind], "already has an integration configured for this environment"
  end

  test "still prevents duplicate web_push kind per environment" do
    duplicate = WebPushIntegration.new(
      account: accounts(:acme),
      environment: environments(:production),
      vendor: "web_push",
      config: {}
    )
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:kind], "already has an integration configured for this environment"
  end
end
