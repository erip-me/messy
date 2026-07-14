# Enrolls a customer into a drip when they enter its trigger segment, then
# schedules the first step. Honors the drip's re-entry policy:
#   - allow_reentry == false : never enroll if the customer has ever been enrolled
#   - allow_reentry == true  : enroll unless an active enrollment already exists
class DripEnroller
  # start_at: when the sequence clock begins. Defaults to now; backfill passes a
  # staggered time so a mass enrollment doesn't fire step 0 for everyone at once.
  def initialize(drip, customer, membership: nil, start_at: nil)
    @drip = drip
    @customer = customer
    @membership = membership
    @start_at = start_at
  end

  def enroll
    return unless @drip.active?
    return if already_enrolled?

    base = @start_at || Time.current
    enrollment = @customer.drip_enrollments.create!(
      account_id: @drip.account_id,
      drip_campaign: @drip,
      segment_membership: @membership,
      status: "active",
      current_position: 0,
      entered_at: Time.current,
      anchor_at: base
    )

    first = @drip.ordered_steps.first
    if first.nil?
      enrollment.update!(status: "completed", completed_at: Time.current)
      return enrollment
    end

    run_at = base + first.delay_days.days
    enrollment.update!(next_run_at: run_at)
    DripScheduler.enqueue(enrollment, run_at)
    enrollment
  end

  private

  def already_enrolled?
    scope = @customer.drip_enrollments.where(drip_campaign_id: @drip.id)
    @drip.allow_reentry ? scope.active.exists? : scope.exists?
  end
end
