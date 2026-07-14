require "test_helper"

class AnalyticsTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    ActiveJob::Base.queue_adapter = :test
    @account = accounts(:acme)
    @user = users(:admin)
    # Capture the kwargs Analytics.track hands to the delivery job, without
    # depending on ActiveJob's brittle keyword-arg serialization in assertions.
    @captured = []
    captured = @captured
    AnalyticsEventJob.define_singleton_method(:perform_later) { |**kw| captured << kw }
  end

  teardown do
    AnalyticsEventJob.singleton_class.send(:remove_method, :perform_later)
    ActiveJob::Base.queue_adapter = :solid_queue
    ENV.delete("POSTHOG_KEY")
  end

  test "is a no-op when POSTHOG_KEY is unset" do
    ENV.delete("POSTHOG_KEY")
    Analytics.track("integration_created", account: @account, user: @user)
    assert_empty @captured
  end

  test "keys the event to the user's id when configured" do
    ENV["POSTHOG_KEY"] = "phc_test"
    Analytics.track("integration_created", account: @account, user: @user, properties: { kind: "email" })

    assert_equal 1, @captured.size
    ev = @captured.first
    assert_equal "integration_created", ev[:event]
    assert_equal @user.id.to_s, ev[:distinct_id]
    assert_equal @account.id, ev[:account_id]
    assert_equal @account.name, ev[:account_name]
    assert_equal @user.email, ev[:user_email]
    assert_equal({ "kind" => "email" }, ev[:properties])
  end

  test "falls back to an account-scoped distinct_id for events with no user" do
    ENV["POSTHOG_KEY"] = "phc_test"
    Analytics.track("campaign_sent", account: @account, user: nil)

    assert_equal "account_#{@account.id}", @captured.first[:distinct_id]
  end

  test "does nothing without an account" do
    ENV["POSTHOG_KEY"] = "phc_test"
    Analytics.track("integration_created", account: nil, user: @user)
    assert_empty @captured
  end
end
