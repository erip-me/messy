require "test_helper"

class SmsMessageTest < ActiveSupport::TestCase
  fixtures :all

  test "validates to presence" do
    message = SmsMessage.new(
      account: accounts(:acme),
      environment: environments(:production),
      to: nil,
      body: "Test SMS"
    )
    assert_not message.valid?
    assert_includes message.errors[:to], "can't be blank"
  end

  test "validates body presence" do
    message = SmsMessage.new(
      account: accounts(:acme),
      environment: environments(:production),
      to: "+15551234567",
      body: nil
    )
    assert_not message.valid?
    assert_includes message.errors[:body], "can't be blank"
  end
end
