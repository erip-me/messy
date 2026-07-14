require "test_helper"

class PublishScheduledSocialPostsJobTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    ActiveJob::Base.queue_adapter = :test
    @region = social_regions(:pakistan) # Asia/Karachi (UTC+5)
  end
  teardown { ActiveJob::Base.queue_adapter = :solid_queue }

  # A day readied the way the app requires it: a selected creative that carries
  # imagery (an all-text day can no longer be marked ready).
  def ready_post(date:, post_hour:)
    post = @region.social_posts.create!(post_date: date, post_hour: post_hour)
    alt = post.social_alternatives.create!(source: :generated, position: 0)
    alt.feed_media.attach(io: StringIO.new("img"), filename: "f.png", content_type: "image/png")
    post.update!(feed_alternative: alt, status: :ready)
    post
  end

  test "enqueues a ready today post once local time is at/past its effective hour" do
    travel_to Time.utc(2026, 7, 10, 6, 0) do # 11:00 in Asia/Karachi
      ready = ready_post(date: @region.local_today, post_hour: 9)

      assert_enqueued_with(job: PublishSocialPostJob, args: [ready.id]) do
        PublishScheduledSocialPostsJob.perform_now
      end
    end
  end

  test "skips a post whose hour has not arrived yet" do
    travel_to Time.utc(2026, 7, 10, 6, 0) do # 11:00 local
      ready_post(date: @region.local_today, post_hour: 15)

      assert_no_enqueued_jobs only: PublishSocialPostJob do
        PublishScheduledSocialPostsJob.perform_now
      end
    end
  end

  test "skips pending days and past days" do
    travel_to Time.utc(2026, 7, 10, 6, 0) do
      @region.social_posts.create!(post_date: @region.local_today, status: :pending, post_hour: 0)
      ready_post(date: @region.local_today - 1, post_hour: 0)

      assert_no_enqueued_jobs only: PublishSocialPostJob do
        PublishScheduledSocialPostsJob.perform_now
      end
    end
  end
end
