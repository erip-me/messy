require "test_helper"

class LogCampaignActivityJobTest < ActiveJob::TestCase
  test "creates customer activity record" do
    customer = customers(:john)
    env = environments(:production)

    assert_difference -> { CustomerActivity.count }, 1 do
      LogCampaignActivityJob.new.perform(
        account_id: accounts(:acme).id,
        customer_id: customer.id,
        environment_id: env.id,
        activity_type: "campaign_sent",
        properties: { campaign_id: 1, campaign_name: "Test" }
      )
    end

    activity = CustomerActivity.last
    assert_equal "campaign_sent", activity.activity_type
    assert_equal customer.id, activity.customer_id
    assert_equal env.id, activity.environment_id
    assert_equal "Test", activity.properties["campaign_name"]
  end
end
