# Safety-net sweeper: recovers enrollments whose scheduled DripAdvanceJob was
# lost (e.g. queue restart/crash). It only picks up enrollments that are
# *overdue past a grace window* — a freshly-due enrollment's own scheduled job
# fires within seconds, so re-enqueueing it here would just race that job. The
# engine is idempotent per tick (row lock + premature-job guard), so recovering
# a still-pending tick is safe.
class DripSweepJob < ApplicationJob
  queue_as :default

  # How long past next_run_at before we treat an enrollment as stuck.
  STUCK_AFTER = 10.minutes

  def perform
    DripEnrollment.active
      .where.not(next_run_at: nil)
      .where(next_run_at: ..STUCK_AFTER.ago)
      .find_each do |enrollment|
        DripAdvanceJob.perform_later(enrollment.id)
      end
  end
end
