# Centralizes enqueueing the next drip tick. A run time at or before now means
# the step should fire immediately (this is what makes "skip collapses delay"
# work: a skipped step leaves the anchor unchanged, so the next step's computed
# run time can land in the past and runs right away).
module DripScheduler
  module_function

  def enqueue(enrollment, run_at)
    if run_at.nil? || run_at <= Time.current
      DripAdvanceJob.perform_later(enrollment.id)
    else
      DripAdvanceJob.set(wait_until: run_at).perform_later(enrollment.id)
    end
  end
end
