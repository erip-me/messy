require "test_helper"

class WebPushIntegrationTest < ActiveSupport::TestCase
  test "sets kind to web_push on validation" do
    wp = WebPushIntegration.new(account: accounts(:acme), config: {})
    wp.valid?
    assert wp.web_push?
  end

  test "config accessors read from config hash" do
    wp = integrations(:web_push)
    assert_equal "BNbxGYNMhEIi5k", wp.vapid_public_key
    assert_equal "test_vapid_private", wp.vapid_private_key
    assert_equal "mailto:test@example.com", wp.vapid_subject
  end

  test "resolve_subscriptions looks up web tokens by customer email" do
    wp = integrations(:web_push)
    subs = wp.send(:resolve_subscriptions, "john@example.com", accounts(:acme))
    assert_equal 1, subs.count
    assert_equal device_tokens(:johns_web), subs.first
  end

  test "resolve_subscriptions returns empty for unknown customer" do
    wp = integrations(:web_push)
    subs = wp.send(:resolve_subscriptions, "nobody@example.com", accounts(:acme))
    assert_empty subs
  end

  test "resolve_subscriptions ignores non-web tokens" do
    wp = integrations(:web_push)
    subs = wp.send(:resolve_subscriptions, "john@example.com", accounts(:acme))
    tokens = subs.map(&:token)
    assert_not_includes tokens, device_tokens(:johns_iphone).token
    assert_not_includes tokens, device_tokens(:johns_android).token
  end

  test "deliver! raises when no web subscriptions found" do
    message = WebPushMessage.new(
      account: accounts(:acme),
      environment: environments(:production),
      to: "nobody@example.com",
      body: "Test push",
      status: :pending
    )
    message.save!

    assert_raises(NoTokensError) do
      integrations(:web_push).deliver!(message)
    end
  end

  test "parse_subscription handles valid JSON" do
    wp = integrations(:web_push)
    sub = wp.send(:parse_subscription, '{"endpoint":"https://example.com","keys":{"p256dh":"abc","auth":"xyz"}}')
    assert_equal "https://example.com", sub["endpoint"]
    assert_equal "abc", sub.dig("keys", "p256dh")
  end

  test "parse_subscription falls back for non-JSON" do
    wp = integrations(:web_push)
    sub = wp.send(:parse_subscription, "https://example.com/push/sub123")
    assert_equal "https://example.com/push/sub123", sub["endpoint"]
  end
end
