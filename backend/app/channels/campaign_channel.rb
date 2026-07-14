class CampaignChannel < ApplicationCable::Channel
  def subscribed
    reject and return unless current_user

    campaign = Campaign.find_by(id: params[:campaign_id], account_id: current_user.account_id)
    reject and return unless campaign

    stream_from "campaign_#{params[:campaign_id]}"
  end
end
