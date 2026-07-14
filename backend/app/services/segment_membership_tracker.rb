# Diffs a customer's current segment membership against the recorded history and
# writes enter/exit rows. Enter events log activity and enroll the customer into
# any active drip keyed to that segment; exit events end active drip enrollments
# for drips configured to exit on segment leave.
#
# History is preserved: an exit sets exited_at (it does not delete the row), so a
# later re-entry creates a fresh membership row and the full enter/exit timeline
# is queryable.
class SegmentMembershipTracker
  def initialize(customer)
    @customer = customer
    @account = customer.account
  end

  def sync
    active = @customer.segment_memberships.active.index_by(&:segment_id)

    segments = @account.segments.to_a
    return if segments.empty?

    matched_ids = matching_segment_ids(segments)

    segments.each do |segment|
      currently_in = matched_ids.include?(segment.id)
      membership = active[segment.id]

      if currently_in && membership.nil?
        enter(segment)
      elsif !currently_in && membership
        leave(segment, membership)
      end
    end
  end

  private

  # Evaluates every segment's condition tree against this single already-loaded
  # customer in ONE round-trip instead of one EXISTS query per segment. Each
  # segment becomes an EXISTS(...) column over the customer-scoped relation that
  # SegmentEvaluator builds, so we recover the full set of matching segment ids
  # from a single row.
  def matching_segment_ids(segments)
    scope = @account.customers.where(id: @customer.id)
    selects = segments.map do |segment|
      rel = SegmentEvaluator.new(scope, segment.conditions).evaluate
      "EXISTS (#{rel.select('1').to_sql}) AS seg_#{segment.id}"
    end

    row = ActiveRecord::Base.connection.select_one("SELECT #{selects.join(', ')}")
    return [] if row.nil?

    bool = ActiveModel::Type::Boolean.new
    segments.select { |s| bool.cast(row["seg_#{s.id}"]) }.map(&:id)
  end

  def enter(segment)
    membership = @customer.segment_memberships.create!(
      account: @account, segment: segment, entered_at: Time.current
    )
    log(segment, "segment_entered")

    DripCampaign.where(account_id: @account.id, segment_id: segment.id, status: "active").find_each do |drip|
      DripEnroller.new(drip, @customer, membership: membership).enroll
    end
  end

  def leave(segment, membership)
    membership.update!(exited_at: Time.current)
    log(segment, "segment_exited")

    drip_ids = DripCampaign.where(
      account_id: @account.id, segment_id: segment.id, status: "active", exit_on_segment_leave: true
    ).pluck(:id)
    return if drip_ids.empty?

    @customer.drip_enrollments.active.where(drip_campaign_id: drip_ids)
      .update_all(status: "exited", exited_at: Time.current, next_run_at: nil)
  end

  def log(segment, activity_type)
    CustomerActivity.create!(
      account: @account,
      customer: @customer,
      environment: nil,
      activity_type: activity_type,
      properties: { segment_id: segment.id, segment_name: segment.name }
    )
  end
end
