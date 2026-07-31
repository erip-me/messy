# Live updates for a region's posting log. SocialPostDelivery broadcasts each
# status change to "social_region_<id>"; the calendar's posting-log panel
# subscribes here. Scoped: a user may only stream a region their account owns.
class SocialRegionChannel < ApplicationCable::Channel
  def subscribed
    account_id = subscription_account_id
    reject and return unless account_id

    region = SocialRegion.find_by(id: params[:region_id], account_id: account_id)
    reject and return unless region

    stream_from "social_region_#{region.id}"
  end
end
