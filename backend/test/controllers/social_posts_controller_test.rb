require "test_helper"

class SocialPostsControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    ActiveJob::Base.queue_adapter = :test
    @admin = users(:admin)
    @region = social_regions(:pakistan)
    @post = @region.social_posts.create!(post_date: @region.local_today)
    @alt = @post.social_alternatives.create!(source: :generated, position: 0, headline: "H")
    @alt.feed_media.attach(io: StringIO.new("img"), filename: "f.png", content_type: "image/png")
  end
  teardown { ActiveJob::Base.queue_adapter = :solid_queue }

  test "calendar returns the month's posts for a region" do
    get "/social_regions/#{@region.id}/calendar?month=#{@region.local_today.strftime('%Y-%m')}",
        headers: auth_headers(@admin), as: :json

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal @region.id, json["region"]["id"]
    assert(json["posts"].any? { |p| p["id"] == @post.id })
  end

  test "picks a slot and marks the day ready" do
    patch "/social_posts/#{@post.id}",
          params: { feed_alternative_id: @alt.id, ready: true },
          headers: auth_headers(@admin), as: :json

    assert_response :success
    @post.reload
    assert @post.ready?
    assert_equal @alt.id, @post.feed_alternative_id
  end

  test "cannot mark a past day ready" do
    past = @region.social_posts.create!(post_date: @region.local_today - 2)
    pa = past.social_alternatives.create!(source: :generated, position: 0)

    patch "/social_posts/#{past.id}",
          params: { feed_alternative_id: pa.id, ready: true },
          headers: auth_headers(@admin), as: :json

    assert_response :unprocessable_entity
    assert_not past.reload.ready?
  end

  test "cannot mark ready without a selection" do
    patch "/social_posts/#{@post.id}", params: { ready: true },
          headers: auth_headers(@admin), as: :json
    assert_response :unprocessable_entity
  end

  test "cannot mark ready when the selected creative has no image or video" do
    bare = @post.social_alternatives.create!(source: :generated, position: 1, headline: "text only")

    patch "/social_posts/#{@post.id}",
          params: { feed_alternative_id: bare.id, ready: true },
          headers: auth_headers(@admin), as: :json

    assert_response :unprocessable_entity
    assert_not @post.reload.ready?
  end

  test "publish_now rejects a day whose selected creative has no media" do
    bare = @post.social_alternatives.create!(source: :generated, position: 1, headline: "text only")
    @post.update_columns(feed_alternative_id: bare.id, status: SocialPost.statuses[:ready])

    assert_no_enqueued_jobs do
      post "/social_posts/#{@post.id}/publish_now", headers: auth_headers(@admin), as: :json
    end
    assert_response :unprocessable_entity
  end

  test "saves and returns a per-post hour override" do
    patch "/social_posts/#{@post.id}", params: { post_hour: 15 },
          headers: auth_headers(@admin), as: :json

    assert_response :success
    assert_equal 15, JSON.parse(response.body)["post_hour"]
    assert_equal 15, @post.reload.post_hour
  end

  test "publish_now enqueues a publish job for today's selected day" do
    @post.update!(feed_alternative: @alt, status: :ready)

    assert_enqueued_with(job: PublishSocialPostJob, args: [@post.id]) do
      post "/social_posts/#{@post.id}/publish_now", headers: auth_headers(@admin), as: :json
    end
    assert_response :success
  end

  test "members can view a region's calendar" do
    get "/social_regions/#{@region.id}/calendar", headers: auth_headers(users(:regular)), as: :json
    assert_response :success
  end
end
