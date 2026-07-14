# Enrolls customers already in the trigger segment when a drip is activated, so
# starting a drip reaches the current audience (not only future entrants).
# DripEnroller dedups, so re-activating a paused drip won't double-enroll.
#
# Step 0 fires are STAGGERED (ENROLLMENTS_PER_SECOND) instead of all at once, so
# activating a drip over a large segment doesn't flood the delivery pipeline /
# trip provider rate limits the way an unthrottled blast would.
class DripBackfillJob < ApplicationJob
  queue_as :default

  ENROLLMENTS_PER_SECOND = 10

  def perform(drip_id)
    drip = DripCampaign.find_by(id: drip_id)
    return unless drip&.active? && drip.segment

    # Skip customers already enrolled without a per-member query (only relevant
    # when re-entry is off; with re-entry, DripEnroller checks active runs).
    already = drip.allow_reentry ? Set.new : drip.drip_enrollments.pluck(:customer_id).to_set

    base = Time.current
    index = 0
    members = SegmentEvaluator.new(drip.account.customers, drip.segment.conditions).evaluate
    members.find_each do |customer|
      next if already.include?(customer.id)

      start_at = base + (index / ENROLLMENTS_PER_SECOND.to_f).seconds
      DripEnroller.new(drip, customer, start_at: start_at).enroll
      index += 1
    end
  end
end
