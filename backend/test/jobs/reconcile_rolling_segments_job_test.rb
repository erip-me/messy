require "test_helper"

class ReconcileRollingSegmentsJobTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup { ActiveJob::Base.queue_adapter = :test }
  teardown { ActiveJob::Base.queue_adapter = :solid_queue }

  test "re-syncs only customers who aged into or out of a rolling segment" do
    account = accounts(:acme)
    customers(:john).update!(custom_attributes: { "last_seen_at" => 200.days.ago.iso8601 })
    customers(:jane).update!(custom_attributes: { "last_seen_at" => 10.days.ago.iso8601 })
    segment = account.segments.create!(name: "Inactive", conditions: {
      "operator" => "and",
      "conditions" => [{ "attribute" => "custom.last_seen_at", "operator" => "more_than_days_ago", "value" => "180" }]
    })
    # jane is recorded as a member but no longer matches; john matches but isn't recorded.
    segment.segment_memberships.create!(account: account, customer: customers(:jane), entered_at: 1.year.ago)

    assert_enqueued_jobs 2, only: RecomputeSegmentMembershipsJob do
      ReconcileRollingSegmentsJob.perform_now
    end
    assert_equal 1, segment.reload.customer_count
  end
end
