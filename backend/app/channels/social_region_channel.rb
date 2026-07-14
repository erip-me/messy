# Live updates for a region's posting log. SocialPostDelivery broadcasts each
# status change to "social_region_<id>"; the calendar's posting-log panel
# subscribes here. Scoped: a user may only stream a region their account owns.
class SocialRegionChannel < ApplicationCable::Channel
  def subscribed
    reject and return unless current_user

    region = SocialRegion.find_by(id: params[:region_id], account_id: current_user.account_id)
    reject and return unless region

    stream_from "social_region_#{region.id}"
  end
end
