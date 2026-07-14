# The drip execution engine. Each invocation processes exactly one step for one
# enrollment, then schedules the next tick. Timing model (per product decision):
#
#   * Delays anchor on the last step ACTUALLY SENT (enrollment.anchor_at).
#   * A step's condition is evaluated lazily, at fire time, against the
#     customer's CURRENT attributes.
#   * "Skip collapses delay": when a step is skipped, anchor_at is left unchanged,
#     so the next step's run time = anchor_at + next.delay_days may land in the
#     past and fire immediately (the skipped step's delay is effectively nullified).
#   * If the drip exits on segment leave and the customer no longer matches the
#     trigger segment, the enrollment exits before doing any work.
class DripAdvanceJob < ApplicationJob
  queue_as :default

  # Transient failures retry with backoff. After they're exhausted, record the
  # step as failed and advance so one bad step (e.g. a broken Liquid template)
  # can't trap the enrollment in an infinite retry loop via the sweeper.
  retry_on StandardError, wait: :polynomially_longer, attempts: 5 do |job, error|
    job.send(:record_terminal_failure, error)
  end

  def perform(enrollment_id)
    enrollment = DripEnrollment.find_by(id: enrollment_id)
    return unless enrollment

    # Row lock serializes concurrent ticks for the same enrollment (a scheduled
    # job racing the sweeper, or a retry) so a step can't be processed twice.
    # The whole tick — send + execution record + advance — is one transaction:
    # a crash rolls back the message creation too, so retries don't double-send.
    enrollment.with_lock { process_due_step(enrollment) }
  end

  private

  def process_due_step(enrollment)
    return unless enrollment.active?
    # A stale/duplicate job whose step already advanced (next_run_at now in the
    # future) must not fire the next step early.
    return if enrollment.next_run_at && enrollment.next_run_at > Time.current

    drip = enrollment.drip_campaign
    return exit_enrollment(enrollment) if drip.exit_on_segment_leave && !in_segment?(enrollment)

    steps = drip.ordered_steps
    step = steps[enrollment.current_position]
    return complete(enrollment) if step.nil?

    if condition_met?(step, enrollment.customer)
      result = DripStepSender.call(enrollment, step)
      record_execution(enrollment, step, status: result.status, message: result.message, reason: result.reason)
      # The anchor only advances on an actual send. A skipped, suppressed, or
      # failed step leaves it unchanged, so the next step's delay collapses.
      enrollment.anchor_at = Time.current if result.status == "sent"
    else
      record_execution(enrollment, step, status: "skipped", reason: "condition not met")
      return exit_enrollment(enrollment) if step.on_fail == "exit"
      # plain skip: leave anchor_at unchanged so the next delay collapses
    end

    advance(enrollment, steps)
  end

  # Invoked once retries are exhausted: record the failing step and move on.
  def record_terminal_failure(error)
    enrollment = DripEnrollment.find_by(id: arguments.first)
    return unless enrollment&.active?

    enrollment.with_lock do
      steps = enrollment.drip_campaign.ordered_steps
      step = steps[enrollment.current_position]
      next unless step

      record_execution(enrollment, step, status: "failed", reason: error.message.to_s[0, 500])
      advance(enrollment, steps)
    end
  end

  def advance(enrollment, steps)
    next_position = enrollment.current_position + 1
    next_step = steps[next_position]

    if next_step.nil?
      enrollment.assign_attributes(current_position: next_position, status: "completed",
                                   completed_at: Time.current, next_run_at: nil)
      enrollment.save!
      return
    end

    run_at = (enrollment.anchor_at || Time.current) + next_step.delay_days.days
    enrollment.assign_attributes(current_position: next_position, next_run_at: run_at)
    enrollment.save!
    DripScheduler.enqueue(enrollment, run_at)
  end

  def condition_met?(step, customer)
    return true unless step.conditional?

    SegmentEvaluator.new(customer.account.customers.where(id: customer.id), step.conditions).evaluate.exists?
  end

  def in_segment?(enrollment)
    segment = enrollment.drip_campaign.segment
    SegmentEvaluator.new(enrollment.account.customers.where(id: enrollment.customer_id), segment.conditions).evaluate.exists?
  end

  def record_execution(enrollment, step, status:, message: nil, reason: nil)
    enrollment.drip_step_executions.create!(
      drip_step: step,
      account_id: enrollment.account_id,
      status: status,
      message_id: message&.id,
      skip_reason: reason,
      scheduled_for: enrollment.next_run_at,
      evaluated_at: Time.current,
      sent_at: (status == "sent" ? Time.current : nil)
    )
  end

  def complete(enrollment)
    enrollment.update!(status: "completed", completed_at: Time.current, next_run_at: nil)
  end

  def exit_enrollment(enrollment)
    enrollment.update!(status: "exited", exited_at: Time.current, next_run_at: nil)
  end
end
