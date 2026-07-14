require "test_helper"

class EmailMessageTest < ActiveSupport::TestCase
  fixtures :all

  test "validates to presence" do
    message = EmailMessage.new(
      account: accounts(:acme),
      environment: environments(:production),
      to: nil,
      subject: "Test",
      body: "<p>Test</p>"
    )
    assert_not message.valid?
    assert_includes message.errors[:to], "can't be blank"
  end

  test "validates subject presence" do
    message = EmailMessage.new(
      account: accounts(:acme),
      environment: environments(:production),
      to: "test@example.com",
      subject: nil,
      body: "<p>Test</p>"
    )
    assert_not message.valid?
    assert_includes message.errors[:subject], "can't be blank"
  end

  test "validates body presence" do
    message = EmailMessage.new(
      account: accounts(:acme),
      environment: environments(:production),
      to: "test@example.com",
      subject: "Test",
      body: nil
    )
    assert_not message.valid?
    assert_includes message.errors[:body], "can't be blank"
  end
end
