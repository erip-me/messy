# Publishes one day's selected slots to every channel linked to its region.
# Guards ensure a day is only ever posted on its own date in region tz (never a
# past day, even if readied late) and only from `ready`/`failed`. Idempotent — a
# target already posted is skipped — so a retry or a re-sweep never double-posts.
# Also used by the admin "publish now" retry.
class PublishSocialPostJob < ApplicationJob
  queue_as :default
  retry_on StandardError, wait: 30.seconds, attempts: 3

  def perform(post_id)
    post = SocialPost.find_by(id: post_id)
    return unless post
    return unless post.social_region.active?
    return unless post.postable_today?
    return unless post.ready? || post.failed?

    SocialPublisher.publish_post(post)
  end
end
