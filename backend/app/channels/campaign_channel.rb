class CampaignChannel < ApplicationCable::Channel
  def subscribed
    account_id = subscription_account_id
    reject and return unless account_id

    campaign = Campaign.find_by(id: params[:campaign_id], account_id: account_id)
    reject and return unless campaign

    stream_from "campaign_#{params[:campaign_id]}"
  end
end
