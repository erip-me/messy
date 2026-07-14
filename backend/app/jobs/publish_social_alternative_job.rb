# Ad-hoc "post now": publishes one creative's slot to every channel linked to the
# region, immediately, without picking it as the day's feed/reel or changing the
# day's status. For one-off posts or reposts from the archive — so it is NOT
# restricted to today's date.
class PublishSocialAlternativeJob < ApplicationJob
  queue_as :default

  def perform(post_id, alternative_id, slot, channels = nil)
    post = SocialPost.find_by(id: post_id)
    alt = SocialAlternative.find_by(id: alternative_id)
    return unless post && alt

    SocialPublisher.new.publish_alternative_now(post, alt, slot, channels: channels)
  end
end
