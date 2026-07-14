require "test_helper"

class DripEnrollerTest < ActiveSupport::TestCase
  setup do
    @account = accounts(:acme)
    @segment = @account.segments.create!(name: "Sellers",
      conditions: { "operator" => "and", "conditions" => [{ "attribute" => "custom.is_seller", "operator" => "equals", "value" => "true" }] })
    @customer = @account.customers.create!(email: "enroll@x.test", custom_attributes: { "is_seller" => true })
    ProcessMessageJob.stubs(:perform_later)
  end

  def build_drip(allow_reentry:)
    drip = @account.drip_campaigns.create!(segment: @segment, name: "D", environment: environments(:production),
                                           status: "active", allow_reentry: allow_reentry)
    drip.drip_steps.create!(account: @account, position: 0, template: templates(:welcome), delay_days: 0)
    drip
  end

  test "does not enroll into a non-active drip" do
    drip = build_drip(allow_reentry: false)
    drip.update!(status: "draft")
    DripEnroller.new(drip, @customer).enroll
    assert_equal 0, @customer.drip_enrollments.count
  end

  test "no re-entry: a customer who already ran the drip is not re-enrolled" do
    drip = build_drip(allow_reentry: false)
    first = DripEnroller.new(drip, @customer).enroll
    first.update!(status: "completed")

    DripEnroller.new(drip, @customer).enroll
    assert_equal 1, @customer.drip_enrollments.where(drip_campaign: drip).count
  end

  test "allow_reentry: a completed customer can be enrolled again" do
    drip = build_drip(allow_reentry: true)
    first = DripEnroller.new(drip, @customer).enroll
    first.update!(status: "completed")

    DripEnroller.new(drip, @customer).enroll
    assert_equal 2, @customer.drip_enrollments.where(drip_campaign: drip).count
  end

  test "allow_reentry still avoids duplicate concurrent active enrollments" do
    drip = build_drip(allow_reentry: true)
    DripEnroller.new(drip, @customer).enroll
    DripEnroller.new(drip, @customer).enroll
    assert_equal 1, @customer.drip_enrollments.active.where(drip_campaign: drip).count
  end
end
