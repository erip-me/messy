require "test_helper"

class FcmIntegrationTest < ActiveSupport::TestCase
  test "sets kind to mobile_push on validation" do
    fcm = FcmIntegration.new(account: accounts(:acme), config: {})
    fcm.valid?
    assert fcm.mobile_push?
  end

  test "config accessors" do
    fcm = integrations(:fcm)
    assert_equal "test-project", fcm.project_id
    assert_equal "test_server_key", fcm.server_key
  end

  test "resolve_tokens returns raw token when to is a long string" do
    fcm = integrations(:fcm)
    tokens = fcm.send(:resolve_tokens, "a" * 64, accounts(:acme))
    assert_equal ["a" * 64], tokens
  end

  test "resolve_tokens includes android and ios when no APNs integration" do
    fcm = integrations(:fcm)
    # Remove the APNs integration so FCM handles both platforms
    integrations(:apns).update!(active: false)

    tokens = fcm.send(:resolve_tokens, "john@example.com", accounts(:acme))
    assert_includes tokens, device_tokens(:johns_iphone).token
    assert_includes tokens, device_tokens(:johns_android).token

    integrations(:apns).update!(active: true)
  end

  test "resolve_tokens excludes ios when APNs integration exists" do
    fcm = integrations(:fcm)
    # APNs is active in fixtures, so FCM should only take android
    fcm.instance_variable_set(:@target_platforms, nil) # clear memoization

    tokens = fcm.send(:resolve_tokens, "john@example.com", accounts(:acme))
    assert_includes tokens, device_tokens(:johns_android).token
    assert_not_includes tokens, device_tokens(:johns_iphone).token
  end

  test "target_platforms is memoized" do
    fcm = integrations(:fcm)
    fcm.instance_variable_set(:@target_platforms, nil)

    result1 = fcm.send(:target_platforms)
    result2 = fcm.send(:target_platforms)
    assert_same result1, result2
  end

  test "build_fcm_client uses StringIO for service_account_json" do
    fcm = FcmIntegration.new(
      account: accounts(:acme),
      config: { "project_id" => "test", "service_account_json" => '{"type":"service_account"}' }
    )

    FCM.expects(:new).with { |io, proj| io.is_a?(StringIO) && proj == "test" }
    fcm.send(:build_fcm_client)
  end

  test "build_fcm_client uses server_key when no service_account_json" do
    fcm = FcmIntegration.new(
      account: accounts(:acme),
      config: { "project_id" => "test", "server_key" => "legacy_key" }
    )

    FCM.expects(:new).with("legacy_key", "test")
    fcm.send(:build_fcm_client)
  end
end
