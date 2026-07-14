require "test_helper"

class DripProjectionServiceTest < ActiveSupport::TestCase
  setup do
    @account = accounts(:acme)
    @segment = @account.segments.create!(name: "Sellers",
      conditions: { "operator" => "and", "conditions" => [{ "attribute" => "custom.is_seller", "operator" => "equals", "value" => "true" }] })
    # 3 sellers (2 without a product, 1 with), plus 1 non-seller outside the segment.
    @account.customers.create!(email: "a@x.test", custom_attributes: { "is_seller" => true })
    @account.customers.create!(email: "b@x.test", custom_attributes: { "is_seller" => true })
    @account.customers.create!(email: "c@x.test", custom_attributes: { "is_seller" => true, "product_uploaded" => "yes" })
    @account.customers.create!(email: "d@x.test", custom_attributes: { "is_seller" => false })
  end

  def not_uploaded
    { "operator" => "and", "conditions" => [{ "attribute" => "custom.product_uploaded", "operator" => "is_blank" }] }
  end

  test "counts who hits each step, with skip keeping the population intact" do
    steps = [
      { conditions: {}, on_fail: "skip" },
      { conditions: not_uploaded, on_fail: "skip" },
    ]
    result = DripProjectionService.new(@account, @segment, steps).call

    assert_equal 3, result[:segment_total]
    assert_equal({ position: 0, reachable: 3, hitting: 3, skipped: 0, suppressed: 0 }, result[:steps][0])
    # c uploaded -> skipped, but still in the population (skip)
    assert_equal({ position: 1, reachable: 3, hitting: 2, skipped: 1, suppressed: 0 }, result[:steps][1])
  end

  test "an exit step shrinks the population for later steps" do
    steps = [
      { conditions: not_uploaded, on_fail: "exit" },
      { conditions: {}, on_fail: "skip" },
    ]
    result = DripProjectionService.new(@account, @segment, steps).call

    assert_equal({ position: 0, reachable: 3, hitting: 2, skipped: 1, suppressed: 0 }, result[:steps][0])
    # c exited at step 0, so only 2 reach step 1
    assert_equal({ position: 1, reachable: 2, hitting: 2, skipped: 0, suppressed: 0 }, result[:steps][1])
  end

  test "returns zeros when there is no segment" do
    assert_equal({ segment_total: 0, steps: [] }, DripProjectionService.new(@account, nil, []).call)
  end

  test "customers unsubscribed from the step channel count as suppressed, not receiving" do
    @account.customers.find_by(email: "a@x.test").unsubscribe_from!("email")
    steps = [{ conditions: {}, on_fail: "skip", channel: "email" }]
    result = DripProjectionService.new(@account, @segment, steps).call

    assert_equal({ position: 0, reachable: 3, hitting: 2, skipped: 0, suppressed: 1 }, result[:steps][0])
  end

  test "projection unsubscribe filter is per-channel" do
    @account.customers.find_by(email: "a@x.test").unsubscribe_from!("email")
    steps = [{ conditions: {}, on_fail: "skip", channel: "sms" }]
    result = DripProjectionService.new(@account, @segment, steps).call

    # email unsubscribe must not reduce an SMS step
    assert_equal 3, result[:steps][0][:hitting]
    assert_equal 0, result[:steps][0][:suppressed]
  end

  test "projection excludes customers opted out of marketing" do
    @account.customers.find_by(email: "a@x.test").unsubscribe_from_category!("marketing")
    steps = [{ conditions: {}, on_fail: "skip", channel: "email" }]
    result = DripProjectionService.new(@account, @segment, steps).call

    assert_equal({ position: 0, reachable: 3, hitting: 2, skipped: 0, suppressed: 1 }, result[:steps][0])
  end
end
