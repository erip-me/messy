require "test_helper"

class RuleTest < ActiveSupport::TestCase
  fixtures :all

  test "channel_type returns correct type name" do
    rule = rules(:allow_internal)
    assert_equal "email", rule.channel_type
  end

  test "passes? returns :allow when condition matches and outcome is allow" do
    rule = rules(:allow_internal)
    message = messages(:email_one)
    rcpt = "domain == 'acme.com'"

    result = rule.passes?(message, rcpt)
    assert_equal :allow, result
  end

  test "passes? returns :deny when condition matches and outcome is deny" do
    rule = rules(:block_external)
    message = messages(:email_one)
    rcpt = "domain != 'acme.com'"

    result = rule.passes?(message, rcpt)
    assert_equal :deny, result
  end

  test "passes? returns :continue when condition doesn't match" do
    rule = rules(:allow_internal)
    message = messages(:email_one)
    rcpt = "no-match-at-all"

    result = rule.passes?(message, rcpt)
    assert_equal :continue, result
  end

  test "passes? matches case-insensitively when recipient has different case" do
    rule = rules(:allow_internal)
    message = messages(:email_one)
    rcpt = "DOMAIN == 'ACME.COM'"

    result = rule.passes?(message, rcpt)
    assert_equal :allow, result
  end

  test "passes? matches case-insensitively when condition has different case" do
    rule = rules(:block_external)
    message = messages(:email_one)
    rcpt = "DOMAIN != 'ACME.COM'"

    result = rule.passes?(message, rcpt)
    assert_equal :deny, result
  end

  test "passes? matches with mixed case recipient and condition" do
    rule = rules(:allow_internal)
    message = messages(:email_one)
    rcpt = "Domain == 'Acme.Com'"

    result = rule.passes?(message, rcpt)
    assert_equal :allow, result
  end
end
