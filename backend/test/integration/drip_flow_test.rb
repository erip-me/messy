require "test_helper"
require "active_support/testing/time_helpers"

# End-to-end simulations of customers flowing through multi-step / multi-channel
# drips. These drive the real pipeline:
#
#   attributes change -> SegmentMembershipTracker (enter/exit) -> DripEnroller
#   -> DripAdvanceJob (engine) -> DripStepSender (creates the transactional Message)
#
# Time is simulated with travel_to; `drain` plays the role of the scheduler/sweeper
# by running every active enrollment whose next_run_at is due at the current instant
# (looping so that skip/suppress steps that collapse their delay fire immediately).
class DripFlowTest < ActionDispatch::IntegrationTest
  include ActiveSupport::Testing::TimeHelpers

  KYC_VERIFIED = {
    "operator" => "and",
    "conditions" => [{ "attribute" => "custom.kyc", "operator" => "equals", "value" => "verified" }],
  }.freeze

  setup do
    @account = accounts(:acme)
    @env = environments(:production)
    @t0 = Time.utc(2026, 3, 1, 9, 0, 0)
    ProcessMessageJob.stubs(:perform_later) # don't run the delivery pipeline

    @segment = @account.segments.create!(
      name: "Drip Sellers",
      conditions: { "operator" => "and", "conditions" => [{ "attribute" => "custom.is_seller", "operator" => "equals", "value" => "true" }] }
    )
    @email_t = template("email", "Drip Email")
    @sms_t   = template("sms", "Drip SMS")
    @push_t  = template("push", "Drip Push")
  end

  # --- helpers ---------------------------------------------------------------

  def template(channel, name)
    @account.templates.create!(
      environment: @env, name: name, trigger: "flow_#{channel}",
      channel: channel, subject: (channel == "email" ? "Hi {{first_name}}" : nil),
      body: "Hello {{first_name}} via #{channel}", body_format: "html"
    )
  end

  def make_drip(steps:, status: "active", **opts)
    drip = @account.drip_campaigns.create!({ name: "Flow", segment: @segment, environment: @env, status: status }.merge(opts))
    steps.each_with_index do |s, i|
      drip.drip_steps.create!(account: @account, position: i, template: s[:template],
        channel: s[:channel], delay_days: s[:delay] || 0,
        conditions: s[:conditions] || {}, on_fail: s[:on_fail] || "skip")
    end
    drip
  end

  def seller(email, attrs = {})
    @account.customers.create!(email: email, phone: "+15550000001",
      custom_attributes: { "is_seller" => true }.merge(attrs))
  end

  # what RecomputeSegmentMembershipsJob runs on an attribute change
  def recompute(customer)
    SegmentMembershipTracker.new(customer.reload).sync
  end

  # run all due enrollments at the current (frozen) time, repeatedly, so collapsed
  # delays fire within the same instant
  def drain(max_passes = 25)
    max_passes.times do
      due = DripEnrollment.active.where.not(next_run_at: nil).where("next_run_at <= ?", Time.current).pluck(:id)
      break if due.empty?
      due.each { |id| DripAdvanceJob.perform_now(id) }
    end
  end

  def messages_for(drip)
    Message.where(drip_campaign_id: drip.id).order(:created_at, :id)
  end

  def execution(drip, customer, position)
    enr = drip.drip_enrollments.find_by(customer: customer)
    step = drip.drip_steps.find_by(position: position)
    enr.drip_step_executions.find_by(drip_step: step)
  end

  # --- 1. happy path: multi-channel, rolling delays, full completion ---------

  test "multi-channel drip sends every step in order with rolling cumulative delays" do
    drip = make_drip(steps: [
      { channel: "email", template: @email_t, delay: 0 },
      { channel: "sms",   template: @sms_t,   delay: 2 },
      { channel: "push",  template: @push_t,  delay: 3 },
    ])
    c = seller("happy@x.test")

    travel_to(@t0)            { recompute(c); drain } # step 0 (email)
    travel_to(@t0 + 2.days)   { drain }               # step 1 (sms)
    travel_to(@t0 + 5.days)   { drain }               # step 2 (push) -> day 5 = 2 + 3

    msgs = messages_for(drip).to_a
    assert_equal %w[EmailMessage SmsMessage MobilePushMessage], msgs.map(&:type)
    assert_equal [@email_t.id, @sms_t.id, @push_t.id], msgs.map(&:template_id)
    assert_equal [@t0.to_i, (@t0 + 2.days).to_i, (@t0 + 5.days).to_i], msgs.map { |m| m.created_at.to_i }
    # SMS routed to the phone, not the email
    assert_equal c.phone, msgs[1].to
    assert_equal c.email, msgs[0].to

    assert_equal "completed", drip.drip_enrollments.find_by(customer: c).status
  end

  # --- 2. new customer entering via the identify API gets enrolled -----------

  test "a customer identified into the segment is enrolled and receives step 0" do
    drip = make_drip(steps: [{ channel: "email", template: @email_t, delay: 0 }])

    travel_to(@t0) do
      post "/customers/identify",
        params: { email: "entrant@x.test", custom_attributes: { is_seller: "true" } },
        headers: api_key_headers(@env)
      assert_response :success

      customer = @account.customers.find_by(email: "entrant@x.test")
      RecomputeSegmentMembershipsJob.perform_now(customer.id) # the worker runs the enqueued job
      drain

      assert_equal 1, drip.drip_enrollments.where(customer: customer).count
      assert_equal ["entrant@x.test"], messages_for(drip).map(&:to)
      assert CustomerActivity.exists?(customer: customer, activity_type: "segment_entered")
    end
  end

  # --- 3. customer exits mid-drip by leaving the segment ---------------------

  test "leaving the segment mid-drip exits the enrollment when exit_on_segment_leave" do
    drip = make_drip(exit_on_segment_leave: true, steps: [
      { channel: "email", template: @email_t, delay: 0 },
      { channel: "email", template: @email_t, delay: 3 },
      { channel: "email", template: @email_t, delay: 3 },
    ])
    c = seller("leaver@x.test")

    travel_to(@t0)          { recompute(c); drain } # step 0
    travel_to(@t0 + 3.days) { drain }               # step 1
    travel_to(@t0 + 4.days) do
      c.update!(custom_attributes: { "is_seller" => false }) # leaves the segment
      recompute(c)
    end
    travel_to(@t0 + 6.days) { drain }               # step 2 would fire — but exited

    enr = drip.drip_enrollments.find_by(customer: c)
    assert_equal "exited", enr.status
    assert_not_nil enr.exited_at
    assert_equal 2, messages_for(drip).count
    assert CustomerActivity.exists?(customer: c, activity_type: "segment_exited")
  end

  test "leaving the segment does NOT stop a drip configured to continue" do
    drip = make_drip(exit_on_segment_leave: false, steps: [
      { channel: "email", template: @email_t, delay: 0 },
      { channel: "email", template: @email_t, delay: 3 },
    ])
    c = seller("stayer@x.test")

    travel_to(@t0) { recompute(c); drain }
    travel_to(@t0 + 1.day) { c.update!(custom_attributes: { "is_seller" => false }); recompute(c) }
    travel_to(@t0 + 3.days) { drain } # step 1 still sends

    assert_equal "completed", drip.drip_enrollments.find_by(customer: c).status
    assert_equal 2, messages_for(drip).count
  end

  # --- 4. step restrictions: skip vs exit ------------------------------------

  test "a step whose restriction fails is skipped and its delay collapses (x y skip(z) m)" do
    drip = make_drip(steps: [
      { channel: "email", template: @email_t, delay: 0 },                                      # x
      { channel: "email", template: @email_t, delay: 3 },                                      # y
      { channel: "email", template: @email_t, delay: 3, conditions: KYC_VERIFIED, on_fail: "skip" }, # z
      { channel: "email", template: @email_t, delay: 3 },                                      # m
    ])
    c = seller("skip@x.test", "kyc" => "pending") # z fails

    travel_to(@t0)          { recompute(c); drain } # x @ day 0
    travel_to(@t0 + 3.days) { drain }               # y @ day 3
    travel_to(@t0 + 6.days) { drain }               # z skipped, m collapses to day 6

    msgs = messages_for(drip).to_a
    assert_equal 3, msgs.size
    assert_equal [0, 1, 3], msgs.map { |m| drip.drip_steps.find(m.drip_step_id).position }
    assert_equal (@t0 + 6.days).to_i, msgs.last.created_at.to_i, "m fires at z's gate (day 6), not day 9"
    assert_equal "skipped", execution(drip, c, 2).status
    assert_equal "completed", drip.drip_enrollments.find_by(customer: c).status
  end

  test "a step restriction with on_fail=exit ends the drip" do
    drip = make_drip(steps: [
      { channel: "email", template: @email_t, delay: 0 },
      { channel: "email", template: @email_t, delay: 3, conditions: KYC_VERIFIED, on_fail: "exit" },
      { channel: "email", template: @email_t, delay: 3 },
    ])
    c = seller("exit@x.test", "kyc" => "pending")

    travel_to(@t0)          { recompute(c); drain }
    travel_to(@t0 + 3.days) { drain } # condition fails -> exit
    travel_to(@t0 + 6.days) { drain } # nothing

    assert_equal "exited", drip.drip_enrollments.find_by(customer: c).status
    assert_equal 1, messages_for(drip).count
    assert_equal "skipped", execution(drip, c, 1).status
  end

  # --- 5. restrictions are evaluated lazily, at fire time --------------------

  test "restrictions use the customer's state at fire time, not enrollment time" do
    drip = make_drip(steps: [
      { channel: "email", template: @email_t, delay: 0 },
      { channel: "email", template: @email_t, delay: 3, conditions: KYC_VERIFIED, on_fail: "skip" },
    ])
    c = seller("lazy@x.test", "kyc" => "verified") # would pass at enrollment

    travel_to(@t0) { recompute(c); drain }
    travel_to(@t0 + 3.days) do
      c.update!(custom_attributes: c.custom_attributes.merge("kyc" => "pending")) # now fails
      drain
    end

    assert_equal "skipped", execution(drip, c, 1).status
    assert_equal 1, messages_for(drip).count
  end

  # --- 6. unsubscribe mid-flight is per-channel ------------------------------

  test "unsubscribing from a channel suppresses that step but other channels still send" do
    drip = make_drip(steps: [
      { channel: "email", template: @email_t, delay: 0 },
      { channel: "email", template: @email_t, delay: 2 },
      { channel: "sms",   template: @sms_t,   delay: 2 },
    ])
    c = seller("unsub@x.test")

    travel_to(@t0) { recompute(c); drain }                     # step 0 email sent
    travel_to(@t0 + 1.day) { c.reload.unsubscribe_from!("email") }
    # at day 2 the email step is suppressed; since it did not "send", the sms step's
    # delay collapses and it fires in the same instant (sms not unsubscribed).
    travel_to(@t0 + 2.days) { drain }

    assert_equal "suppressed", execution(drip, c, 1).status
    assert_equal "sent",       execution(drip, c, 2).status
    assert_equal %w[EmailMessage SmsMessage], messages_for(drip).map(&:type)
    assert_equal "completed", drip.drip_enrollments.find_by(customer: c).status
  end

  # --- 7. enrollment scope: backfill everyone vs new-only --------------------

  test "activating with enroll_existing_on_start backfills current segment members" do
    s1 = seller("e1@x.test")
    s2 = seller("e2@x.test")
    @account.customers.create!(email: "notseller@x.test", custom_attributes: { "is_seller" => false })
    drip = make_drip(status: "draft", enroll_existing_on_start: true, steps: [{ channel: "email", template: @email_t, delay: 0 }])

    travel_to(@t0) do
      drip.update!(status: "active")
      DripBackfillJob.perform_now(drip.id) # what activate enqueues; step-0 sends are staggered
    end
    # Past the stagger window, both due sends fire.
    travel_to(@t0 + 5.seconds) { drain }

    assert_equal 2, drip.drip_enrollments.count
    assert_equal ["e1@x.test", "e2@x.test"], messages_for(drip).map(&:to).sort
    assert_equal [s1.id, s2.id].sort, drip.drip_enrollments.pluck(:customer_id).sort
  end

  test "a new-entrants-only drip ignores existing members but enrolls future entrants" do
    seller("alreadythere@x.test") # in the segment before activation, must be ignored
    drip = make_drip(status: "draft", enroll_existing_on_start: false, steps: [{ channel: "email", template: @email_t, delay: 0 }])

    travel_to(@t0) do
      drip.update!(status: "active") # no backfill enqueued
      drain
    end
    assert_equal 0, drip.drip_enrollments.count

    travel_to(@t0 + 1.day) do
      newbie = seller("newbie@x.test")
      recompute(newbie) # enters after start
      drain
    end

    assert_equal 1, drip.drip_enrollments.count
    assert_equal ["newbie@x.test"], messages_for(drip).map(&:to)
  end

  # --- 8. re-entry policy ----------------------------------------------------

  test "no re-entry: completing then re-entering the segment does not re-enroll" do
    drip = make_drip(allow_reentry: false, steps: [{ channel: "email", template: @email_t, delay: 0 }])
    c = seller("noreentry@x.test")

    travel_to(@t0) { recompute(c); drain }
    assert_equal "completed", drip.drip_enrollments.find_by(customer: c).status

    travel_to(@t0 + 1.day)  { c.update!(custom_attributes: { "is_seller" => false }); recompute(c) }
    travel_to(@t0 + 2.days) { c.update!(custom_attributes: { "is_seller" => true });  recompute(c); drain }

    assert_equal 1, drip.drip_enrollments.where(customer: c).count
    assert_equal 1, messages_for(drip).count
  end

  test "allow re-entry: re-entering the segment starts a fresh run" do
    drip = make_drip(allow_reentry: true, steps: [{ channel: "email", template: @email_t, delay: 0 }])
    c = seller("reentry@x.test")

    travel_to(@t0) { recompute(c); drain }
    travel_to(@t0 + 1.day)  { c.update!(custom_attributes: { "is_seller" => false }); recompute(c) }
    travel_to(@t0 + 2.days) { c.update!(custom_attributes: { "is_seller" => true });  recompute(c); drain }

    assert_equal 2, drip.drip_enrollments.where(customer: c).count
    assert_equal 2, messages_for(drip).count
  end

  # --- 9. concurrent cohort moving through together --------------------------

  test "multiple customers flow through independently" do
    drip = make_drip(steps: [
      { channel: "email", template: @email_t, delay: 0 },
      { channel: "email", template: @email_t, delay: 2 },
    ])
    a = seller("coh-a@x.test")
    b = seller("coh-b@x.test")

    travel_to(@t0) { recompute(a); recompute(b); drain } # both get step 0
    # b leaves before step 1
    travel_to(@t0 + 1.day) { b.update!(custom_attributes: { "is_seller" => false }); recompute(b) }
    travel_to(@t0 + 2.days) { drain } # a gets step 1; b is gone

    assert_equal "completed", drip.drip_enrollments.find_by(customer: a).status
    assert_equal "exited",    drip.drip_enrollments.find_by(customer: b).status
    assert_equal 2, messages_for(drip).where(to: "coh-a@x.test").count
    assert_equal 1, messages_for(drip).where(to: "coh-b@x.test").count
  end

  # --- 10. messages are attributable to the drip / step ----------------------

  test "messages can be filtered by drip and by specific step" do
    drip = make_drip(steps: [
      { channel: "email", template: @email_t, delay: 0 },
      { channel: "email", template: @email_t, delay: 2 },
    ])
    c = seller("filter@x.test")
    travel_to(@t0)          { recompute(c); drain }
    travel_to(@t0 + 2.days) { drain }
    step0 = drip.drip_steps.find_by(position: 0)

    get "/messages", params: { drip_id: drip.id }, headers: api_key_headers(@env)
    assert_response :success
    assert_equal 2, JSON.parse(response.body)["data"].size

    get "/messages", params: { drip_id: drip.id, drip_step_id: step0.id }, headers: api_key_headers(@env)
    data = JSON.parse(response.body)["data"]
    assert_equal 1, data.size
    assert_equal step0.id, data.first["drip_step_id"]
  end

  test "a drip step reports how many messages it has sent" do
    drip = make_drip(steps: [{ channel: "email", template: @email_t, delay: 0 }])
    travel_to(@t0) do
      recompute(seller("s1@x.test"))
      recompute(seller("s2@x.test"))
      drain
    end

    get "/drips/#{drip.id}", headers: auth_headers(users(:admin))
    assert_response :success
    step = JSON.parse(response.body)["steps"].first
    assert_equal 2, step["sent_count"]
  end

  # --- 11. unsubscribe link / compliance -------------------------------------

  test "drip emails render an unsubscribe link tied to the message" do
    tmpl = @account.templates.create!(environment: @env, name: "Unsub", trigger: "flow_unsub", channel: "email",
      subject: "Hi", body: 'Hello {{first_name}} — <a href="{{unsubscribe_url}}">unsubscribe</a>', body_format: "html")
    drip = make_drip(steps: [{ channel: "email", template: tmpl, delay: 0 }])
    c = seller("link@x.test")
    travel_to(@t0) { recompute(c); drain }

    msg = messages_for(drip).first
    assert_includes msg.body, "/track/#{msg.tracking_token}/unsubscribe"
  end

  test "a drip stamps its sending identity onto every message it sends" do
    identity = @account.sending_identities.create!(from_name: "Peter", from_email: "peter@lalaaji.com")
    drip = make_drip(steps: [{ channel: "email", template: @email_t, delay: 0 }])
    drip.update!(sending_identity: identity)
    c = seller("ident@x.test")

    travel_to(@t0) { recompute(c); drain }

    msg = messages_for(drip).first
    assert_equal identity.id, msg.sending_identity_id
    assert_equal "Peter <peter@lalaaji.com>", SendingIdentity.from_line(msg.sending_identity, msg.account)
  end

  test "the transactional unsubscribe link unsubscribes the customer from the channel" do
    c = seller("clicks@x.test")
    msg = EmailMessage.create!(account: @account, environment: @env, to: c.email, subject: "x", body: "y")

    get "/track/#{msg.tracking_token}/unsubscribe"
    assert_response :success
    assert c.reload.unsubscribed_from?("email")
  end

  # --- 12. drip unsubscribe is marketing-only (system emails keep flowing) ---

  test "clicking a drip unsubscribe opts out of marketing only, and stops later steps" do
    tmpl = @account.templates.create!(environment: @env, name: "Mkt", trigger: "flow_mkt", channel: "email",
      subject: "Hi", body: 'Hi <a href="{{unsubscribe_url}}">unsub</a>', body_format: "html")
    drip = make_drip(steps: [
      { channel: "email", template: tmpl, delay: 0 },
      { channel: "email", template: tmpl, delay: 2 },
    ])
    c = seller("optout@x.test")
    travel_to(@t0) { recompute(c); drain } # step 0 sends

    msg = messages_for(drip).first
    get "/track/#{msg.tracking_token}/unsubscribe"
    assert_response :success

    c.reload
    assert c.unsubscribed_from_category?("marketing"), "drip unsubscribe opts out of marketing"
    assert_not c.unsubscribed_from?("email"), "the channel itself is NOT blocked, so system emails still send"

    travel_to(@t0 + 2.days) { drain } # step 1 is now suppressed
    assert_equal "suppressed", execution(drip, c, 1).status
    assert_equal 1, messages_for(drip).count, "no further drip messages after opting out"
  end
end
