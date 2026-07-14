require "test_helper"

class RulePushTest < ActiveSupport::TestCase
  test "TYPE_MAP includes push and web_push" do
    assert_equal "MobilePushRule", Rule::TYPE_MAP["push"]
    assert_equal "WebPushRule", Rule::TYPE_MAP["web_push"]
  end

  test "MobilePushRule is a Rule subclass" do
    rule = MobilePushRule.new(
      account: accounts(:acme),
      environment: environments(:production),
      name: "Allow all push",
      condition: "@",
      outcome: :allow,
      active: true
    )
    assert rule.is_a?(Rule)
    assert rule.valid?
  end

  test "WebPushRule is a Rule subclass" do
    rule = WebPushRule.new(
      account: accounts(:acme),
      environment: environments(:production),
      name: "Allow all web push",
      condition: "@",
      outcome: :allow,
      active: true
    )
    assert rule.is_a?(Rule)
    assert rule.valid?
  end
end
