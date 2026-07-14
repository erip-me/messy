require "test_helper"

class AnalyticsDailyRollupJobTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    ActiveJob::Base.queue_adapter = :test
    @account = accounts(:acme)
    @captured = []
    captured = @captured
    AnalyticsEventJob.define_singleton_method(:perform_later) { |**kw| captured << kw }
  end

  teardown do
    AnalyticsEventJob.singleton_class.send(:remove_method, :perform_later)
    ActiveJob::Base.queue_adapter = :solid_queue
    ENV.delete("POSTHOG_KEY")
  end

  test "is a no-op when analytics is disabled" do
    ENV.delete("POSTHOG_KEY")
    AnalyticsDailyRollupJob.perform_now
    assert_empty @captured
  end

  test "emits one aggregated event per account with sent+delivered summed" do
    ENV["POSTHOG_KEY"] = "phc_test"
    yesterday = Date.current - 1

    # Stub the grouped count ([account_id, status] => n) so the test exercises
    # the aggregation/mapping rather than message-fixture plumbing.
    counts = {
      [ @account.id, Message.statuses["sent"] ]      => 3,
      [ @account.id, Message.statuses["delivered"] ] => 5,
      [ @account.id, Message.statuses["failed"] ]    => 1
    }
    Message.stubs(:where).returns(stub(group: stub(count: counts)))

    AnalyticsDailyRollupJob.perform_now

    assert_equal 1, @captured.size
    ev = @captured.first
    assert_equal "messages_daily", ev[:event]
    assert_equal "account_#{@account.id}", ev[:distinct_id]
    props = ev[:properties] # keys stringified by Analytics.track
    assert_equal yesterday.iso8601, props["date"]
    assert_equal 9, props["total"]
    assert_equal 8, props["sent"]
    assert_equal 5, props["delivered"]
    assert_equal 1, props["failed"]
    assert_equal 0, props["rejected"]
  end
end
