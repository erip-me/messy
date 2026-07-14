require "test_helper"

class SegmentMembershipTrackerTest < ActiveSupport::TestCase
  setup do
    @account = accounts(:acme)
    @segment = @account.segments.create!(
      name: "Sellers",
      conditions: {
        "operator" => "and",
        "conditions" => [
          { "attribute" => "custom.is_seller", "operator" => "equals", "value" => "true" }
        ]
      }
    )
    @customer = @account.customers.create!(email: "tracked@sellers.test", custom_attributes: { "is_seller" => true })
  end

  test "records an enter row and logs activity when the customer matches" do
    assert_difference -> { @customer.segment_memberships.active.where(segment: @segment).count }, 1 do
      SegmentMembershipTracker.new(@customer).sync
    end

    membership = @customer.segment_memberships.active.find_by(segment: @segment)
    assert membership
    assert_nil membership.exited_at
    assert CustomerActivity.exists?(customer: @customer, activity_type: "segment_entered")
  end

  test "is idempotent — re-syncing while still matching does not duplicate membership" do
    SegmentMembershipTracker.new(@customer).sync
    assert_no_difference -> { @customer.segment_memberships.count } do
      SegmentMembershipTracker.new(@customer.reload).sync
    end
  end

  test "closes the membership and logs an exit when the customer stops matching" do
    SegmentMembershipTracker.new(@customer).sync
    @customer.update!(custom_attributes: { "is_seller" => false })

    SegmentMembershipTracker.new(@customer.reload).sync

    assert_equal 0, @customer.segment_memberships.active.where(segment: @segment).count
    membership = @customer.segment_memberships.find_by(segment: @segment)
    assert_not_nil membership.exited_at
    assert CustomerActivity.exists?(customer: @customer, activity_type: "segment_exited")
  end

  test "re-entry after exit creates a fresh membership row preserving history" do
    SegmentMembershipTracker.new(@customer).sync
    @customer.update!(custom_attributes: { "is_seller" => false })
    SegmentMembershipTracker.new(@customer.reload).sync
    @customer.update!(custom_attributes: { "is_seller" => true })
    SegmentMembershipTracker.new(@customer.reload).sync

    rows = @customer.segment_memberships.where(segment: @segment).order(:entered_at)
    assert_equal 2, rows.count, "history is preserved as two rows, not overwritten"
    assert_not_nil rows.first.exited_at
    assert_nil rows.last.exited_at
  end

  test "entering a segment enrolls the customer into an active drip on that segment" do
    drip = @account.drip_campaigns.create!(segment: @segment, name: "Seller welcome",
                                           environment: environments(:production), status: "active")
    drip.drip_steps.create!(account: @account, position: 0, template: templates(:welcome), delay_days: 0)

    SegmentMembershipTracker.new(@customer).sync

    assert_equal 1, @customer.drip_enrollments.where(drip_campaign: drip).count
  end

  test "leaving a segment exits active enrollments when the drip exits on leave" do
    drip = @account.drip_campaigns.create!(segment: @segment, name: "Seller welcome",
                                           environment: environments(:production), status: "active",
                                           exit_on_segment_leave: true)
    drip.drip_steps.create!(account: @account, position: 0, template: templates(:welcome), delay_days: 3)
    SegmentMembershipTracker.new(@customer).sync
    enrollment = @customer.drip_enrollments.find_by(drip_campaign: drip)
    assert_equal "active", enrollment.status

    @customer.update!(custom_attributes: { "is_seller" => false })
    SegmentMembershipTracker.new(@customer.reload).sync

    assert_equal "exited", enrollment.reload.status
  end
end
