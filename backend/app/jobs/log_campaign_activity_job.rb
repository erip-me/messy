class LogCampaignActivityJob < ApplicationJob
  queue_as :default

  def perform(account_id:, customer_id:, environment_id:, activity_type:, properties: {})
    CustomerActivity.create!(
      account_id: account_id,
      customer_id: customer_id,
      environment_id: environment_id,
      activity_type: activity_type,
      properties: properties
    )
  end
end
