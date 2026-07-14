require "test_helper"
require "active_support/testing/time_helpers"

class DripAdvanceJobTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::TimeHelpers

  NOT_UPLOADED = {
    "operator" => "and",
    "conditions" => [
      { "attribute" => "custom.product_uploaded", "operator" => "is_blank" }
    ]
  }.freeze

  setup do
    @account = accounts(:acme)
    @environment = environments(:production)
    @template = templates(:welcome)
    @segment = @account.segments.create!(
      name: "Sellers",
      conditions: {
        "operator" => "and",
        "conditions" => [{ "attribute" => "custom.is_seller", "operator" => "equals", "value" => "true" }]
      }
    )
    # Don't actually push messages through the delivery pipeline.
    ProcessMessageJob.stubs(:perform_later)
    @t0 = Time.utc(2026, 1, 1, 12, 0, 0)
  end

  # x -> (3d) y -> (3d, "has not uploaded product") z -> (3d) m
  def build_four_step_drip(exit_on_leave: false)
    drip = @account.drip_campaigns.create!(
      segment: @segment, name: "Seller onboarding", environment: @environment,
      status: "active", exit_on_segment_leave: exit_on_leave
    )
    drip.drip_steps.create!(account: @account, position: 0, template: @template, delay_days: 0)                       # x
    drip.drip_steps.create!(account: @account, position: 1, template: @template, delay_days: 3)                       # y
    drip.drip_steps.create!(account: @account, position: 2, template: @template, delay_days: 3, conditions: NOT_UPLOADED) # z
    drip.drip_steps.create!(account: @account, position: 3, template: @template, delay_days: 3)                       # m
    drip
  end

  def advance(enrollment)
    DripAdvanceJob.perform_now(enrollment.id)
    enrollment.reload
  end

  test "skip collapses the delay: m fires at z's gate time, not 3 days later" do
    drip = build_four_step_drip
    customer = @account.customers.create!(email: "seller@x.test",
      custom_attributes: { "is_seller" => true, "product_uploaded" => "yes" }) # condition for z FAILS

    travel_to @t0 do
      enrollment = DripEnroller.new(drip, customer).enroll
      assert_equal @t0.to_i, enrollment.next_run_at.to_i

      advance(enrollment) # step 0: send x
      assert_equal 1, enrollment.current_position
      assert_equal @t0.to_i, enrollment.anchor_at.to_i
      assert_equal((@t0 + 3.days).to_i, enrollment.next_run_at.to_i)
    end

    travel_to @t0 + 3.days do
      enrollment = drip.drip_enrollments.first
      advance(enrollment) # step 1: send y
      assert_equal 2, enrollment.current_position
      assert_equal((@t0 + 3.days).to_i, enrollment.anchor_at.to_i)
      assert_equal((@t0 + 6.days).to_i, enrollment.next_run_at.to_i)
    end

    travel_to @t0 + 6.days do
      enrollment = drip.drip_enrollments.first
      advance(enrollment) # step 2: z condition fails -> SKIP
      assert_equal 3, enrollment.current_position
      assert_equal((@t0 + 3.days).to_i, enrollment.anchor_at.to_i, "anchor stays on the last SENT step (y)")
      assert_equal((@t0 + 6.days).to_i, enrollment.next_run_at.to_i, "m's delay collapses to now, not t0+9d")

      advance(enrollment) # step 3: m fires immediately
      assert_equal "completed", enrollment.status
    end

    statuses = drip.drip_enrollments.first.drip_step_executions.includes(:drip_step).order("drip_steps.position").map { |e| [e.drip_step.position, e.status] }
    assert_equal [[0, "sent"], [1, "sent"], [2, "skipped"], [3, "sent"]], statuses

    m_exec = drip.drip_enrollments.first.drip_step_executions.joins(:drip_step).where(drip_steps: { position: 3 }).first
    assert_equal((@t0 + 6.days).to_i, m_exec.sent_at.to_i, "m arrives on day 6")

    assert_equal 3, EmailMessage.where(drip_campaign_id: drip.id).count, "x, y, m sent; z skipped"
    assert EmailMessage.where(drip_campaign_id: drip.id, drip_step_id: drip.drip_steps.find_by(position: 0).id).exists?
  end

  test "conditions are evaluated lazily at fire time against current attributes" do
    drip = build_four_step_drip
    # product NOT uploaded at enrollment, so z's condition would pass...
    customer = @account.customers.create!(email: "lazy@x.test", custom_attributes: { "is_seller" => true })

    enrollment = nil
    travel_to(@t0) { enrollment = DripEnroller.new(drip, customer).enroll; advance(enrollment) } # x
    travel_to(@t0 + 3.days) { advance(enrollment) } # y

    travel_to @t0 + 6.days do
      customer.update!(custom_attributes: customer.custom_attributes.merge("product_uploaded" => "yes")) # state changes mid-flight
      advance(enrollment) # z re-evaluated NOW -> skipped
    end

    z_exec = enrollment.drip_step_executions.joins(:drip_step).where(drip_steps: { position: 2 }).first
    assert_equal "skipped", z_exec.status, "uploading the product before z fires skips it"
  end

  test "leaving the trigger segment exits the enrollment when exit_on_segment_leave is set" do
    drip = build_four_step_drip(exit_on_leave: true)
    customer = @account.customers.create!(email: "leaver@x.test", custom_attributes: { "is_seller" => true })

    enrollment = nil
    travel_to(@t0) { enrollment = DripEnroller.new(drip, customer).enroll; advance(enrollment) } # x sent

    travel_to @t0 + 3.days do
      customer.update!(custom_attributes: { "is_seller" => false }) # no longer in segment
      advance(enrollment) # guard trips before sending y
    end

    assert_equal "exited", enrollment.status
    assert_equal 1, EmailMessage.where(drip_campaign_id: drip.id).count, "only x went out"
  end

  test "an unsubscribed customer is suppressed, not sent, and the drip still advances" do
    drip = build_four_step_drip
    customer = @account.customers.create!(email: "unsub@x.test", custom_attributes: { "is_seller" => true })
    customer.unsubscribe_from!("email")

    enrollment = nil
    travel_to(@t0) { enrollment = DripEnroller.new(drip, customer).enroll; advance(enrollment) } # step 0

    exec = enrollment.drip_step_executions.joins(:drip_step).where(drip_steps: { position: 0 }).first
    assert_equal "suppressed", exec.status
    assert_equal 0, EmailMessage.where(drip_campaign_id: drip.id).count
    assert_equal 1, enrollment.current_position, "still advances past the suppressed step"
  end

  # --- idempotency (Fix 1) ---------------------------------------------------

  test "a premature/duplicate tick does not fire the next step early or twice" do
    drip = build_four_step_drip
    customer = @account.customers.create!(email: "dup@x.test", custom_attributes: { "is_seller" => true })

    travel_to @t0 do
      enrollment = DripEnroller.new(drip, customer).enroll
      advance(enrollment)                       # step 0 sent, now waiting until t0+3d for step 1
      assert_equal 1, enrollment.current_position
      assert_equal 1, EmailMessage.where(drip_campaign_id: drip.id).count

      # A duplicate job (e.g. sweeper racing the scheduled job) runs again now —
      # step 1 isn't due until t0+3d, so it must be a no-op.
      advance(enrollment)
      assert_equal 1, enrollment.current_position
      assert_equal 1, EmailMessage.where(drip_campaign_id: drip.id).count
    end
  end

  test "a step cannot be executed twice for the same enrollment (unique index)" do
    drip = build_four_step_drip
    customer = @account.customers.create!(email: "uniq@x.test", custom_attributes: { "is_seller" => true })
    enrollment = travel_to(@t0) { DripEnroller.new(drip, customer).enroll }
    step = drip.drip_steps.find_by(position: 0)

    enrollment.drip_step_executions.create!(drip_step: step, account_id: @account.id, status: "sent")
    assert_raises ActiveRecord::RecordNotUnique do
      enrollment.drip_step_executions.create!(drip_step: step, account_id: @account.id, status: "sent")
    end
  end

  # --- terminal failure recovery (Fix 2) -------------------------------------

  test "after retries are exhausted the failing step is recorded and the drip advances" do
    drip = build_four_step_drip
    customer = @account.customers.create!(email: "boom@x.test", custom_attributes: { "is_seller" => true })
    enrollment = travel_to(@t0) { DripEnroller.new(drip, customer).enroll }

    travel_to @t0 do
      DripAdvanceJob.new(enrollment.id).send(:record_terminal_failure, StandardError.new("liquid blew up"))
    end
    enrollment.reload

    exec = enrollment.drip_step_executions.joins(:drip_step).where(drip_steps: { position: 0 }).first
    assert_equal "failed", exec.status
    assert_equal 1, enrollment.current_position, "advances past the failed step instead of looping"
    assert_equal "active", enrollment.status
  end
end
