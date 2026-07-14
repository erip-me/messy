# The posting log: one publish attempt to one target — a (post, social account,
# slot, channel) tuple. Mirrors CampaignDelivery: carries the result status, the
# provider's returned post id, and any error, and broadcasts status changes over
# ActionCable so the log UI updates live.
class SocialPostDelivery < ApplicationRecord
  belongs_to :social_post
  belongs_to :integration
  belongs_to :account

  enum :slot,    { feed: 0, reel: 1, carousel: 2 }
  enum :channel, { facebook: 0, instagram: 1, linkedin: 2 }
  enum :status,  { pending: 0, posted: 1, failed: 2, skipped: 3 }

  after_save :broadcast_update, if: :saved_change_to_status?

  scope :recent, -> { order(created_at: :desc) }

  # Has this exact target already been posted? Used for scheduler idempotency.
  def self.posted_target?(post_id, integration_id, slot, channel)
    where(social_post_id: post_id, integration_id: integration_id,
          slot: slot, channel: channel, status: :posted).exists?
  end

  def as_log_json
    {
      id: id,
      social_post_id: social_post_id,
      integration_id: integration_id,
      account_name: integration&.label.presence || integration&.vendor,
      slot: slot,
      channel: channel,
      status: status,
      provider_post_id: provider_post_id,
      error_message: error_message,
      posted_at: posted_at&.iso8601,
      created_at: created_at&.iso8601
    }
  end

  private

  def broadcast_update
    ActionCable.server.broadcast(
      "social_region_#{social_post.social_region_id}",
      { type: "delivery_update", delivery: as_log_json }
    )
  end
end
