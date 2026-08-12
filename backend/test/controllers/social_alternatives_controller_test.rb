require "test_helper"

class SocialAlternativesControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    ActiveJob::Base.queue_adapter = :test
    @admin = users(:admin)
    @region = social_regions(:pakistan) # Meta-configured
    @region.update!(linkedin_integration: integrations(:linkedin_social), linkedin_org_id: "999001")
    @post = @region.social_posts.create!(post_date: @region.local_today)
    @alt = @post.social_alternatives.create!(source: :generated, position: 0, headline: "H")
    @alt.feed_media.attach(io: StringIO.new("img"), filename: "f.png", content_type: "image/png")
  end
  teardown { ActiveJob::Base.queue_adapter = :solid_queue }

  test "post_now keeps an explicit LinkedIn channel pick" do
    assert_enqueued_with(job: PublishSocialAlternativeJob, args: [@post.id, @alt.id, "feed", ["linkedin"]]) do
      post "/social_alternatives/#{@alt.id}/post_now",
           params: { slot: "feed", channels: ["linkedin"] }, headers: auth_headers(@admin), as: :json
    end
    assert_response :success
  end

  test "post_now falls back to the carousel slot for a carousel-only variant" do
    carousel = @post.social_alternatives.create!(source: :generated, position: 1, headline: "C")
    2.times { |i| carousel.carousel_media.attach(io: StringIO.new("img#{i}"), filename: "c#{i}.png", content_type: "image/png") }

    assert_enqueued_with(job: PublishSocialAlternativeJob, args: [@post.id, carousel.id, "carousel", nil]) do
      post "/social_alternatives/#{carousel.id}/post_now", headers: auth_headers(@admin), as: :json
    end
    assert_response :success
  end

  test "post_now rejects a variant with no media in any slot" do
    bare = @post.social_alternatives.create!(source: :generated, position: 2, headline: "text only")

    assert_no_enqueued_jobs do
      post "/social_alternatives/#{bare.id}/post_now", headers: auth_headers(@admin), as: :json
    end
    assert_response :unprocessable_entity
  end

  test "post_now honours a mixed pick without dropping LinkedIn" do
    assert_enqueued_with(job: PublishSocialAlternativeJob, args: [@post.id, @alt.id, "feed", %w[facebook linkedin]]) do
      post "/social_alternatives/#{@alt.id}/post_now",
           params: { slot: "feed", channels: %w[facebook linkedin] }, headers: auth_headers(@admin), as: :json
    end
  end
end
