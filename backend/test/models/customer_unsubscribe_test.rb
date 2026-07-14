require "test_helper"

class CustomerUnsubscribeTest < ActiveSupport::TestCase
  test "unsubscribed_from? returns false by default" do
    customer = customers(:john)
    assert_not customer.unsubscribed_from?("email")
    assert_not customer.unsubscribed_from?("sms")
  end

  test "unsubscribe_from! sets channel timestamp" do
    customer = customers(:john)
    customer.unsubscribe_from!("email")
    customer.reload

    assert customer.unsubscribed_from?("email")
    assert_not customer.unsubscribed_from?("sms")
    assert customer.unsubscribed_channels["email"].present?
  end

  test "resubscribe_to! removes channel" do
    customer = customers(:john)
    customer.unsubscribe_from!("email")
    assert customer.unsubscribed_from?("email")

    customer.resubscribe_to!("email")
    customer.reload
    assert_not customer.unsubscribed_from?("email")
  end

  test "multiple channels can be independently managed" do
    customer = customers(:john)
    customer.unsubscribe_from!("email")
    customer.unsubscribe_from!("sms")

    assert customer.unsubscribed_from?("email")
    assert customer.unsubscribed_from?("sms")

    customer.resubscribe_to!("email")
    customer.reload

    assert_not customer.unsubscribed_from?("email")
    assert customer.unsubscribed_from?("sms")
  end

  test "unsubscribe_from! stores reason when provided" do
    customer = customers(:john)
    customer.unsubscribe_from!("email", reason: "bounce")
    customer.reload

    assert customer.unsubscribed_from?("email")
    info = customer.unsubscribe_info("email")
    assert_equal "bounce", info["reason"]
    assert info["at"].present?
  end

  test "unsubscribe_from! without reason stores plain timestamp" do
    customer = customers(:john)
    customer.unsubscribe_from!("email")
    customer.reload

    assert customer.unsubscribed_from?("email")
    info = customer.unsubscribe_info("email")
    assert_nil info["reason"]
    assert info["at"].present?
  end

  test "unsubscribe_info returns nil for subscribed channel" do
    customer = customers(:john)
    assert_nil customer.unsubscribe_info("email")
  end

  # --- category opt-out (drip / marketing) -----------------------------------

  test "marketing opt-out suppresses marketing but not transactional messages" do
    customer = customers(:john)
    customer.unsubscribe_from_category!("marketing")
    customer.reload

    assert customer.unsubscribed_from_category?("marketing")
    assert customer.suppressed_for?(channel: "email", category: "marketing")
    # system/transactional email keeps flowing
    assert_not customer.suppressed_for?(channel: "email", category: "transactional")
    assert_not customer.suppressed_for?(channel: "email")
  end

  test "hard channel block still suppresses every category" do
    customer = customers(:john)
    customer.unsubscribe_from!("email")

    assert customer.suppressed_for?(channel: "email", category: "transactional")
    assert customer.suppressed_for?(channel: "email", category: "marketing")
    # other channels unaffected
    assert_not customer.suppressed_for?(channel: "sms", category: "marketing")
  end

  test "resubscribe_to_category! re-enables marketing" do
    customer = customers(:john)
    customer.unsubscribe_from_category!("marketing")
    assert customer.unsubscribed_from_category?("marketing")

    customer.resubscribe_to_category!("marketing")
    customer.reload
    assert_not customer.unsubscribed_from_category?("marketing")
  end

  test "unsubscribe_info handles both string and hash formats" do
    customer = customers(:john)

    # Old format: plain string timestamp
    customer.update!(unsubscribed_channels: { "email" => "2024-01-01T00:00:00Z" })
    info = customer.unsubscribe_info("email")
    assert_equal "2024-01-01T00:00:00Z", info["at"]
    assert_nil info["reason"]

    # New format: hash with reason
    customer.update!(unsubscribed_channels: { "email" => { "at" => "2024-01-01T00:00:00Z", "reason" => "complaint" } })
    info = customer.unsubscribe_info("email")
    assert_equal "2024-01-01T00:00:00Z", info["at"]
    assert_equal "complaint", info["reason"]
  end
end
