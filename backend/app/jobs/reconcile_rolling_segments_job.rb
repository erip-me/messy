# Rolling-window conditions ("more than N days ago") change their matches as time
# passes, with no customer update to trigger RecomputeSegmentMembershipsJob. Once a
# day, diff each such segment's live matches against its recorded memberships and
# re-sync only the customers who crossed the line, so drip enter/exit still fires.
class ReconcileRollingSegmentsJob < ApplicationJob
  queue_as :default

  def perform
    Segment.where("conditions::text ~ '_days_ago'").find_each do |segment|
      matched = segment.evaluate(segment.account).pluck(:id)
      recorded = segment.segment_memberships.active.pluck(:customer_id)
      ((matched - recorded) | (recorded - matched)).each do |customer_id|
        RecomputeSegmentMembershipsJob.perform_later(customer_id)
      end
    end
  end
end
