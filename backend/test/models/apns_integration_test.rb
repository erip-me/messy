require "test_helper"

class ApnsIntegrationTest < ActiveSupport::TestCase
  test "sets kind to mobile_push on validation" do
    apns = ApnsIntegration.new(account: accounts(:acme), config: {})
    apns.valid?
    assert apns.mobile_push?
  end

  test "config accessors read from config hash" do
    apns = integrations(:apns)
    assert_equal "TEAM123", apns.team_id
    assert_equal "KEY456", apns.key_id
    assert_equal "com.example.testapp", apns.bundle_id
    assert_equal "sandbox", apns.apns_environment
    assert apns.private_key.present?
  end

  test "apns_environment defaults to production" do
    apns = ApnsIntegration.new(account: accounts(:acme), config: {})
    assert_equal "production", apns.apns_environment
  end

  test "resolve_tokens returns raw token when to is a long string" do
    apns = integrations(:apns)
    tokens = apns.send(:resolve_tokens, "a" * 64, accounts(:acme))
    assert_equal ["a" * 64], tokens
  end

  test "resolve_tokens looks up iOS tokens by customer email" do
    apns = integrations(:apns)
    tokens = apns.send(:resolve_tokens, "john@example.com", accounts(:acme))
    assert_includes tokens, device_tokens(:johns_iphone).token
    assert_not_includes tokens, device_tokens(:johns_android).token
  end

  test "resolve_tokens returns empty for unknown customer" do
    apns = integrations(:apns)
    tokens = apns.send(:resolve_tokens, "nobody@example.com", accounts(:acme))
    assert_empty tokens
  end

  test "deliver! raises when no iOS tokens found" do
    message = MobilePushMessage.new(
      account: accounts(:acme),
      environment: environments(:production),
      to: "nobody@example.com",
      body: "Test push",
      status: :pending
    )
    message.save!

    assert_raises(NoTokensError) do
      integrations(:apns).deliver!(message)
    end
  end

  test "deliver! sends to each token via single connection" do
    apns = integrations(:apns)
    message = MobilePushMessage.create!(
      account: accounts(:acme),
      environment: environments(:production),
      to: "john@example.com",
      body: "Test push",
      status: :pending
    )

    connection = mock("apnotic_connection")
    response = mock("apnotic_response")
    response.stubs(:nil?).returns(false)
    response.stubs(:ok?).returns(true)
    response.stubs(:status).returns("200")
    response.stubs(:body).returns("")

    apns.stubs(:build_connection).returns(connection)
    connection.stubs(:push).returns(response)
    connection.expects(:close).once

    apns.deliver!(message)
  end

  test "deliver! deactivates token on 410 response" do
    apns = integrations(:apns)
    token = device_tokens(:johns_iphone)

    # Use a raw token so it's treated as a direct token, not email lookup
    message = MobilePushMessage.create!(
      account: accounts(:acme),
      environment: environments(:production),
      to: token.token.ljust(51, "x"), # ensure > 50 chars
      body: "Test push",
      status: :pending
    )

    connection = mock("apnotic_connection")
    response = mock("apnotic_response")
    response.stubs(:nil?).returns(false)
    response.stubs(:ok?).returns(false)
    response.stubs(:status).returns("410")
    response.stubs(:body).returns("Unregistered")

    apns.stubs(:build_connection).returns(connection)
    connection.stubs(:push).returns(response)
    connection.stubs(:close)

    # Create a DeviceToken with this padded token so deactivate! can find it
    padded_token = token.token.ljust(51, "x")
    dt = DeviceToken.create!(account: accounts(:acme), customer: customers(:john), token: padded_token, platform: :ios)

    assert_raises(RuntimeError) do
      apns.deliver!(message)
    end

    assert_not dt.reload.active
  end
end
