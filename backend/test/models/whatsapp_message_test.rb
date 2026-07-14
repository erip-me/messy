require "test_helper"

class WhatsappMessageTest < ActiveSupport::TestCase
  test "validates to is required" do
    msg = WhatsappMessage.new(body: "test", account: accounts(:acme), environment: environments(:production))
    assert_not msg.valid?
    assert_includes msg.errors[:to], "can't be blank"
  end

  test "validates body is required for text messages" do
    msg = WhatsappMessage.new(to: "+31647508676", account: accounts(:acme), environment: environments(:production))
    assert_not msg.valid?
    assert_includes msg.errors[:body], "can't be blank"
  end

  test "body not required for template messages" do
    msg = WhatsappMessage.new(
      to: "+31647508676",
      subject: "hello_world",
      account: accounts(:acme),
      environment: environments(:production)
    )
    assert msg.valid?, msg.errors.full_messages.join(", ")
    assert_equal "[WhatsApp Template: hello_world]", msg.body
  end
end
