# Re-evaluates a customer's segment membership after their attributes change
# (enqueued from the identify path). Diffs against recorded history, writing
# enter/exit rows and triggering drip enrollment/exit as needed.
class RecomputeSegmentMembershipsJob < ApplicationJob
  queue_as :default

  def perform(customer_id)
    customer = Customer.find_by(id: customer_id)
    return unless customer

    SegmentMembershipTracker.new(customer).sync
  end
end
