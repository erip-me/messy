require "test_helper"

class DripBackfillJobTest < ActiveSupport::TestCase
  setup do
    @account = accounts(:acme)
    @segment = @account.segments.create!(name: "Sellers",
      conditions: { "operator" => "and", "conditions" => [{ "attribute" => "custom.is_seller", "operator" => "equals", "value" => "true" }] })
    @account.customers.create!(email: "s1@x.test", custom_attributes: { "is_seller" => true })
    @account.customers.create!(email: "s2@x.test", custom_attributes: { "is_seller" => true })
    @account.customers.create!(email: "nope@x.test", custom_attributes: { "is_seller" => false })
    ProcessMessageJob.stubs(:perform_later)
  end

  def build_drip(status: "active")
    drip = @account.drip_campaigns.create!(name: "D", segment: @segment, environment: environments(:production), status: status)
    drip.drip_steps.create!(account: @account, position: 0, template: templates(:welcome), delay_days: 0)
    drip
  end

  test "enrolls current segment members and skips non-members" do
    drip = build_drip
    assert_difference -> { drip.drip_enrollments.count }, 2 do
      DripBackfillJob.perform_now(drip.id)
    end
    emails = drip.drip_enrollments.map { |e| e.customer.email }.sort
    assert_equal ["s1@x.test", "s2@x.test"], emails
  end

  test "does nothing for a non-active drip" do
    drip = build_drip(status: "draft")
    assert_no_difference -> { drip.drip_enrollments.count } do
      DripBackfillJob.perform_now(drip.id)
    end
  end

  test "is idempotent for a no-reentry drip" do
    drip = build_drip
    DripBackfillJob.perform_now(drip.id)
    assert_no_difference -> { drip.drip_enrollments.count } do
      DripBackfillJob.perform_now(drip.id)
    end
  end

  test "staggers step-0 fires across enrollments instead of all at once" do
    drip = build_drip # step 0, delay 0
    DripBackfillJob.perform_now(drip.id)

    run_ats = drip.drip_enrollments.pluck(:next_run_at)
    assert_equal 2, run_ats.size
    assert_equal run_ats.uniq.size, run_ats.size, "each enrollment's first send is staggered to a distinct time"
  end
end
