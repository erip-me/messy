# Sweeps every active region and enqueues its ready-today content once the
# region's local time is at or past its post_hour. Using ">=" (not "==") is
# self-healing: a missed tick, or a day marked ready after post_hour, still posts
# at the next tick. Enqueues a PublishSocialPostJob per post (idempotent), so
# re-sweeps never double-post. Registered in config/recurring.yml.
class PublishScheduledSocialPostsJob < ApplicationJob
  queue_as :default

  def perform
    SocialRegion.active.find_each do |region|
      next unless region.configured?

      now = region.local_now
      region.social_posts.ready_for(now.to_date).find_each do |post|
        # Gate per post so a per-day time override is honored, not just the region
        # default. ">=" is self-healing across ticks.
        next unless now.hour >= post.effective_post_hour

        PublishSocialPostJob.perform_later(post.id)
      end
    end
  end
end
