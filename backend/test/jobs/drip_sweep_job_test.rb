require "test_helper"

class DripSweepJobTest < ActiveSupport::TestCase
  setup do
    @account = accounts(:acme)
    @segment = @account.segments.create!(name: "S", conditions: { "operator" => "and", "conditions" => [] })
    @drip = @account.drip_campaigns.create!(name: "D", segment: @segment, environment: environments(:production), status: "active")
    @customer = @account.customers.create!(email: "sweep@x.test")
  end

  def enrollment(status:, next_run_at:)
    @account.drip_enrollments.create!(drip_campaign: @drip, customer: @customer, status: status, next_run_at: next_run_at)
  end

  test "re-enqueues active enrollments stuck past the grace window" do
    due = enrollment(status: "active", next_run_at: 1.hour.ago)

    DripAdvanceJob.expects(:perform_later).with(due.id).once
    DripSweepJob.perform_now
  end

  test "ignores future, completed, null, and recently-due (within grace) enrollments" do
    enrollment(status: "active", next_run_at: 1.hour.from_now)
    enrollment(status: "completed", next_run_at: 1.hour.ago)
    enrollment(status: "active", next_run_at: nil)
    # Recently due — its own scheduled job is about to run; the sweeper must not race it.
    enrollment(status: "active", next_run_at: 1.minute.ago)

    DripAdvanceJob.expects(:perform_later).never
    DripSweepJob.perform_now
  end
end
