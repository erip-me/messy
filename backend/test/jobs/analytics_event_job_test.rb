require "test_helper"

class AnalyticsEventJobTest < ActiveSupport::TestCase
  teardown do
    ENV.delete("POSTHOG_KEY")
    ENV.delete("POSTHOG_HOST")
  end

  test "does not hit the network when POSTHOG_KEY is unset" do
    ENV.delete("POSTHOG_KEY")
    Net::HTTP.any_instance.expects(:request).never
    AnalyticsEventJob.perform_now(event: "x", distinct_id: "1", account_id: 1)
  end

  test "posts a $groupidentify + event batch associated with the account group" do
    ENV["POSTHOG_KEY"] = "phc_test"
    ENV["POSTHOG_HOST"] = "https://eu.i.posthog.com"

    body = nil
    ok = Net::HTTPOK.new("1.1", "200", "OK") # is_a?(Net::HTTPSuccess) is true
    Net::HTTP.any_instance.stubs(:request).with { |req| body = req.body; true }.returns(ok)

    AnalyticsEventJob.perform_now(
      event: "integration_created",
      distinct_id: "42",
      account_id: 7,
      account_name: "Acme",
      account_plan: "trial",
      account_status: "active",
      user_email: "a@b.com",
      properties: { "kind" => "email" }
    )

    parsed = JSON.parse(body)
    assert_equal "phc_test", parsed["api_key"]

    events = parsed["batch"]
    assert_equal [ "$groupidentify", "integration_created" ], events.map { |e| e["event"] }

    gi = events.first["properties"]
    assert_equal "account", gi["$group_type"]
    assert_equal "7", gi["$group_key"]
    assert_equal "Acme", gi["$group_set"]["name"]

    capture = events.last["properties"]
    assert_equal({ "account" => "7" }, capture["$groups"])
    assert_equal 7, capture["account_id"]
    assert_equal "email", capture["kind"]
    assert_equal({ "email" => "a@b.com" }, capture["$set"])
  end
end
