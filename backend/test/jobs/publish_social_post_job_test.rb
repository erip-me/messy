require "test_helper"

class PublishSocialPostJobTest < ActiveSupport::TestCase
  setup { @region = social_regions(:pakistan) }

  def post_on(date, status)
    post = @region.social_posts.create!(post_date: date)
    alt = post.social_alternatives.create!(source: :generated, position: 0)
    alt.feed_media.attach(io: StringIO.new("img"), filename: "f.png", content_type: "image/png")
    post.update_columns(feed_alternative_id: alt.id, status: SocialPost.statuses[status])
    post
  end

  test "publishes a ready day on its own date" do
    post = post_on(@region.local_today, :ready)
    SocialPublisher.expects(:publish_post).with(post).once
    PublishSocialPostJob.perform_now(post.id)
  end

  # A part-posted day must stay retryable after its date, or the only reachable
  # retry is the ad-hoc one, which re-posts channels that already went out.
  test "retries a failed day after its own date" do
    post = post_on(@region.local_today - 2.days, :failed)
    SocialPublisher.expects(:publish_post).with(post).once
    PublishSocialPostJob.perform_now(post.id)
  end

  test "never posts a ready day readied late" do
    post = post_on(@region.local_today - 1.day, :ready)
    SocialPublisher.expects(:publish_post).never
    PublishSocialPostJob.perform_now(post.id)
  end

  test "skips a pending day" do
    post = post_on(@region.local_today, :pending)
    SocialPublisher.expects(:publish_post).never
    PublishSocialPostJob.perform_now(post.id)
  end

  test "skips a paused region" do
    post = post_on(@region.local_today, :ready)
    @region.update!(active: false)
    SocialPublisher.expects(:publish_post).never
    PublishSocialPostJob.perform_now(post.id)
  end
end
