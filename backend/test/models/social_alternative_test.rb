require "test_helper"

class SocialAlternativeTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    ActiveJob::Base.queue_adapter = :test
    @post = social_regions(:pakistan).social_posts.create!(post_date: Date.current)
    @alt = @post.social_alternatives.create!(source: :generated, position: 0,
                                             headline: "H", body: "B", cta_label: "Sign Up")
  end
  teardown { ActiveJob::Base.queue_adapter = :solid_queue }

  test "caption joins headline, body and cta, dropping blanks" do
    assert_equal "H\n\nB\n\nSign Up", @alt.caption
    @alt.body = ""
    assert_equal "H\n\nSign Up", @alt.caption
  end

  test "carousel_images is images-only and capped at ten" do
    12.times { |i| @alt.carousel_media.attach(io: StringIO.new("i#{i}"), filename: "c#{i}.png", content_type: "image/png") }
    @alt.carousel_media.attach(io: StringIO.new("v"), filename: "v.mp4", content_type: "video/mp4")

    assert_equal 10, @alt.carousel_images.size
    assert @alt.carousel_images.all? { |m| m.blob.content_type.start_with?("image/") }
  end

  test "media_for returns the requested slot, defaulting to feed" do
    @alt.feed_media.attach(io: StringIO.new("i"), filename: "f.png", content_type: "image/png")

    assert @alt.media_for("feed")&.attached?
    assert_nil @alt.media_for("reel")
    assert @alt.media_for&.attached? # default falls back to the feed asset
  end

  test "destroying a picked alternative clears the post's slot" do
    @post.update!(feed_alternative: @alt)
    @alt.destroy!
    assert_nil @post.reload.feed_alternative_id
  end

  test "destroying purges its attached media from storage" do
    @alt.feed_media.attach(io: StringIO.new("i"), filename: "f.png", content_type: "image/png")
    blob = @alt.feed_media.blob

    perform_enqueued_jobs { @alt.destroy! }

    assert_not ActiveStorage::Blob.exists?(blob.id)
  end
end
