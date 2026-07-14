require "test_helper"

class SocialPostTest < ActiveSupport::TestCase
  setup { @region = social_regions(:pakistan) }

  test "postable_today? is true only on region-local today" do
    today = @region.social_posts.create!(post_date: @region.local_today)
    past  = @region.social_posts.create!(post_date: @region.local_today - 1)

    assert today.postable_today?
    assert_not past.postable_today?
    assert past.past?
  end

  test "effective_post_hour uses the override, else the region default" do
    post = @region.social_posts.create!(post_date: @region.local_today)
    assert_equal @region.post_hour, post.effective_post_hour

    post.update!(post_hour: 14)
    assert_equal 14, post.effective_post_hour
  end

  test "post_hour override must be a valid hour" do
    post = @region.social_posts.new(post_date: @region.local_today, post_hour: 25)
    assert_not post.valid?
  end

  test "post_date is unique per region" do
    @region.social_posts.create!(post_date: @region.local_today)
    dup = @region.social_posts.new(post_date: @region.local_today)
    assert_not dup.valid?
  end

  test "selected_slots returns only the picked alternatives" do
    post = @region.social_posts.create!(post_date: @region.local_today)
    alt = post.social_alternatives.create!(source: :generated, position: 0)
    post.update!(feed_alternative: alt)

    assert_equal({ "feed" => alt }, post.selected_slots)
  end

  test "cannot be readied when the selected creative has no media" do
    post = @region.social_posts.create!(post_date: @region.local_today)
    alt = post.social_alternatives.create!(source: :generated, position: 0, headline: "text only")
    post.feed_alternative = alt

    post.status = :ready
    assert_not post.valid?
    assert_not post.publishable_media?

    alt.feed_media.attach(io: StringIO.new("img"), filename: "f.png", content_type: "image/png")
    assert post.publishable_media?
    assert post.valid?
  end

  test "editing an already-ready day does not re-trigger the media requirement" do
    post = @region.social_posts.create!(post_date: @region.local_today)
    alt = post.social_alternatives.create!(source: :generated, position: 0)
    alt.feed_media.attach(io: StringIO.new("img"), filename: "f.png", content_type: "image/png")
    post.update!(feed_alternative: alt, status: :ready) # valid transition (has media)

    # The selection is later cleared (e.g. the variant was deleted), leaving a
    # ready day with no media. An unrelated edit must still save — the media rule
    # only guards the transition into ready, not every subsequent save.
    post.update_columns(feed_alternative_id: nil)
    post.post_hour = 14
    assert post.valid?
    assert post.save
  end
end
