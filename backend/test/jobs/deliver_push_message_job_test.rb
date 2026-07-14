require "test_helper"

class DeliverPushMessageJobTest < ActiveJob::TestCase
  test "delivers push message via FCM and APNs" do
    message = MobilePushMessage.create!(
      account: accounts(:acme),
      environment: environments(:production),
      to: "john@example.com",
      body: "Test push",
      status: :pending
    )

    FcmIntegration.any_instance.stubs(:deliver!)
    ApnsIntegration.any_instance.stubs(:deliver!)

    assert_difference -> { Delivery.count }, 2 do
      DeliverMessageJob.new.perform(message)
    end

    message.reload
    assert_equal "sent", message.status
    assert_not_nil message.sent_at
  end

  test "delivers push via FCM only when no APNs configured" do
    integrations(:apns).update!(active: false)

    message = MobilePushMessage.create!(
      account: accounts(:acme),
      environment: environments(:production),
      to: "john@example.com",
      body: "Test push",
      status: :pending
    )

    FcmIntegration.any_instance.stubs(:deliver!)

    assert_difference -> { Delivery.count }, 1 do
      DeliverMessageJob.new.perform(message)
    end

    message.reload
    assert_equal "sent", message.status

    integrations(:apns).update!(active: true)
  end

  test "fails when no push integrations configured" do
    message = MobilePushMessage.create!(
      account: accounts(:other_co),
      environment: environments(:other_env),
      to: "john@example.com",
      body: "Test push",
      status: :pending
    )

    assert_no_difference -> { Delivery.count } do
      DeliverMessageJob.new.perform(message)
    end

    message.reload
    assert_equal "failed", message.status
  end

  test "raises when all push integrations fail" do
    message = MobilePushMessage.create!(
      account: accounts(:acme),
      environment: environments(:production),
      to: "john@example.com",
      body: "Test push",
      status: :pending
    )

    FcmIntegration.any_instance.stubs(:deliver!).raises(StandardError, "FCM down")
    ApnsIntegration.any_instance.stubs(:deliver!).raises(StandardError, "APNs down")

    assert_raises(RuntimeError, /All push integrations failed/) do
      DeliverMessageJob.new.perform(message)
    end

    deliveries = Delivery.where(message: message)
    assert_equal 2, deliveries.count
    assert deliveries.all? { |d| d.error.present? }
  end

  test "succeeds when only one push integration fails" do
    message = MobilePushMessage.create!(
      account: accounts(:acme),
      environment: environments(:production),
      to: "john@example.com",
      body: "Test push",
      status: :pending
    )

    FcmIntegration.any_instance.stubs(:deliver!)
    ApnsIntegration.any_instance.stubs(:deliver!).raises(StandardError, "APNs down")

    DeliverMessageJob.new.perform(message)

    message.reload
    assert_equal "sent", message.status
  end

  test "web push message uses deliver_single path" do
    message = WebPushMessage.create!(
      account: accounts(:acme),
      environment: environments(:production),
      to: "john@example.com",
      body: "Test web push",
      status: :pending
    )

    WebPushIntegration.any_instance.stubs(:deliver!)

    assert_difference -> { Delivery.count }, 1 do
      DeliverMessageJob.new.perform(message)
    end

    message.reload
    assert_equal "sent", message.status
  end

  test "build_integration returns correct kind for push message types" do
    job = DeliverMessageJob.new

    push_msg = MobilePushMessage.create!(
      account: accounts(:acme), environment: environments(:production),
      to: "test@example.com", body: "test", status: :pending
    )
    assert_equal :mobile_push, job.build_integration(push_msg)&.kind&.to_sym

    web_msg = WebPushMessage.create!(
      account: accounts(:acme), environment: environments(:production),
      to: "test@example.com", body: "test", status: :pending
    )
    assert_equal :web_push, job.build_integration(web_msg)&.kind&.to_sym
  end
end
