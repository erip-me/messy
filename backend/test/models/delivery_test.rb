require "test_helper"

class DeliveryTest < ActiveSupport::TestCase
  fixtures :all

  test "belongs_to message" do
    delivery = deliveries(:email_delivery)
    assert_equal messages(:email_one), delivery.message
  end

  test "belongs_to integration" do
    delivery = deliveries(:email_delivery)
    assert_equal integrations(:ses), delivery.integration
  end

  test "belongs_to account" do
    delivery = deliveries(:email_delivery)
    assert_equal accounts(:acme), delivery.account
  end

  test "validates recipient presence" do
    delivery = Delivery.new(
      account: accounts(:acme),
      message: messages(:email_one),
      integration: integrations(:ses),
      recipient: nil
    )
    assert_not delivery.valid?
    assert_includes delivery.errors[:recipient], "can't be blank"
  end
end
