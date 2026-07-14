# Projects how many customers would hit each step of a drip if it started right
# now, evaluated against customers' CURRENT attributes. Mirrors the runtime
# semantics for counting purposes:
#   - everyone currently in the trigger segment enrolls (backfill on start),
#   - a step's condition decides who is SENT that step ("hitting"),
#   - on_fail == "skip": those who fail still continue to later steps,
#   - on_fail == "exit": those who fail leave the drip, shrinking the population.
#
# steps is an ordered array of hashes with :conditions (segment-DSL hash) and
# :on_fail ("skip" | "exit").
class DripProjectionService
  def initialize(account, segment, steps)
    @account = account
    @segment = segment
    @steps = steps
  end

  def call
    return { segment_total: 0, steps: [] } unless @segment

    base = SegmentEvaluator.new(@account.customers, @segment.conditions).evaluate
    segment_total = base.count

    reachable_scope = base
    rows = @steps.each_with_index.map do |step, i|
      conditions = step[:conditions]
      # Those who match the step's condition (or all, if unconditional).
      matched_scope = conditions.present? ? SegmentEvaluator.new(reachable_scope, conditions).evaluate : reachable_scope
      reachable = reachable_scope.count
      matched = conditions.present? ? matched_scope.count : reachable

      # Of the matched, those unsubscribed from the channel OR opted out of
      # marketing won't receive it (suppressed) — but they stay in the drip.
      # Mirror the runtime suppression filter.
      channel = step[:channel].presence || "email"
      receiving = matched_scope.subscribed_to_channel(channel).subscribed_to_category(Customer::MARKETING_CATEGORY).count
      suppressed = matched - receiving

      row = {
        position: i,
        reachable: reachable,
        hitting: receiving,                 # will actually receive the message
        skipped: reachable - matched,       # condition not met
        suppressed: suppressed,             # matched but unsubscribed from the channel
      }

      # Only "exit" steps shrink the population for subsequent steps; suppression does not.
      reachable_scope = matched_scope if step[:on_fail].to_s == "exit"
      row
    end

    { segment_total: segment_total, steps: rows }
  end
end
