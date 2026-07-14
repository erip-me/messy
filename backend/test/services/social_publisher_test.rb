require "test_helper"

class SocialPublisherTest < ActiveSupport::TestCase
  setup do
    @region = social_regions(:pakistan) # has a token integration + page_id + ig
    @post = @region.social_posts.create!(post_date: @region.local_today)
    @alt = @post.social_alternatives.create!(source: :generated, position: 0,
                                             headline: "H", body: "B", cta_label: "Sign Up")
    @alt.feed_media.attach(io: StringIO.new("img"), filename: "f.png", content_type: "image/png")
    @post.update!(feed_alternative: @alt)

    # Isolate the orchestration from URL generation + the Graph API.
    SocialMedia.stubs(:video?).returns(false)
    SocialMedia.stubs(:public_url).returns("https://cdn.test/f.png")
    SocialMedia.stubs(:jpeg_url).returns("https://cdn.test/f.jpg")
    MetaSocialIntegration.any_instance.stubs(:publish_facebook).returns("fb_1")
    MetaSocialIntegration.any_instance.stubs(:publish_instagram).returns("ig_1")
  end

  test "publishes the selected slot to facebook and instagram and logs each" do
    assert_difference "SocialPostDelivery.count", 2 do
      SocialPublisher.publish_post(@post)
    end

    @post.reload
    assert @post.posted?
    assert_equal %w[facebook instagram], @post.social_post_deliveries.map(&:channel).sort
    assert @post.social_post_deliveries.all?(&:posted?)
  end

  test "a channel failure marks the day failed and records the error" do
    @region.update!(ig_business_account_id: nil) # facebook only
    MetaSocialIntegration.any_instance.stubs(:publish_facebook)
      .raises(MetaSocialIntegration::PublishError.new("boom"))

    SocialPublisher.publish_post(@post)

    @post.reload
    assert @post.failed?
    assert_match "boom", @post.publish_error
    assert @post.social_post_deliveries.first.failed?
  end

  test "is idempotent: an already-posted target is not re-posted" do
    @region.update!(ig_business_account_id: nil) # facebook only

    SocialPublisher.publish_post(@post)
    assert_no_difference "SocialPostDelivery.count" do
      SocialPublisher.publish_post(@post)
    end
  end

  test "post now publishes ad-hoc without changing the day's status" do
    @region.update!(ig_business_account_id: nil) # facebook only

    SocialPublisher.new.publish_alternative_now(@post, @alt, "feed")

    assert_equal "pending", @post.reload.status
    assert_equal 1, @post.social_post_deliveries.count
  end

  test "a disabled default channel is skipped on scheduled posts" do
    @region.update!(post_to_facebook: false)
    MetaSocialIntegration.any_instance.expects(:publish_facebook).never

    SocialPublisher.publish_post(@post)

    @post.reload
    assert @post.posted?
    assert_equal %w[instagram], @post.social_post_deliveries.map(&:channel)
  end

  test "post now honours an explicit channel selection" do
    MetaSocialIntegration.any_instance.expects(:publish_facebook).never

    SocialPublisher.new.publish_alternative_now(@post, @alt, "feed", channels: ["instagram"])

    assert_equal %w[instagram], @post.social_post_deliveries.map(&:channel)
  end

  test "publishes a carousel to facebook and instagram" do
    MetaSocialIntegration.any_instance.stubs(:publish_facebook_carousel).returns("fb_c")
    MetaSocialIntegration.any_instance.stubs(:publish_instagram_carousel).returns("ig_c")
    3.times { |i| @alt.carousel_media.attach(io: StringIO.new("i#{i}"), filename: "c#{i}.png", content_type: "image/png") }
    @post.update!(feed_alternative: nil, carousel_alternative: @alt)

    assert_difference "SocialPostDelivery.count", 2 do
      SocialPublisher.publish_post(@post)
    end

    @post.reload
    assert @post.posted?
    assert_equal %w[carousel], @post.social_post_deliveries.map(&:slot).uniq
    assert_equal %w[facebook instagram], @post.social_post_deliveries.map(&:channel).sort
  end

  test "a carousel with fewer than two images is not published" do
    @alt.carousel_media.attach(io: StringIO.new("i"), filename: "c.png", content_type: "image/png")
    @post.update!(feed_alternative: nil, carousel_alternative: @alt)

    assert_no_difference "SocialPostDelivery.count" do
      SocialPublisher.publish_post(@post)
    end
  end

  test "nothing is published when the region has no page selected" do
    @region.update!(page_id: nil)

    assert_no_difference "SocialPostDelivery.count" do
      SocialPublisher.publish_post(@post)
    end
  end

  # ── LinkedIn ─────────────────────────────────────────────────────────────────

  # Turn the region into a LinkedIn-only target so the LinkedIn branch is isolated
  # from Facebook/Instagram.
  def linkedin_only!
    @region.update!(
      post_to_facebook: false, ig_business_account_id: nil,
      linkedin_integration: integrations(:linkedin_social), linkedin_org_id: "999001"
    )
  end

  test "publishes an image slot to linkedin with the downloaded bytes" do
    linkedin_only!
    captured = nil
    LinkedinSocialIntegration.any_instance.stubs(:publish_organization_post).with do |org_id:, images:, caption:|
      captured = { org_id: org_id, images: images, caption: caption }
      true
    end.returns("urn:li:share:1")

    assert_difference "SocialPostDelivery.count", 1 do
      SocialPublisher.publish_post(@post)
    end

    @post.reload
    assert @post.posted?
    delivery = @post.social_post_deliveries.first
    assert_equal "linkedin", delivery.channel
    assert_equal integrations(:linkedin_social).id, delivery.integration_id
    assert_equal "999001", captured[:org_id]
    assert_equal "img", captured[:images].first[:data]
    assert_equal "image/png", captured[:images].first[:content_type]
  end

  test "a video slot on a linkedin-only region is skipped and the day is marked failed" do
    linkedin_only!
    SocialMedia.unstub(:video?)
    SocialMedia.stubs(:video?).returns(true) # the selected slot is a video
    LinkedinSocialIntegration.any_instance.expects(:publish_organization_post).never

    assert_no_difference "SocialPostDelivery.count" do
      SocialPublisher.publish_post(@post)
    end

    @post.reload
    # Nothing was publishable, so it fails visibly rather than looping in `ready`.
    assert @post.failed?
    assert_match "Nothing could be published", @post.publish_error
  end

  test "publishes a carousel to linkedin as a multi-image post" do
    linkedin_only!
    LinkedinSocialIntegration.any_instance.stubs(:publish_organization_post).returns("urn:li:share:c")
    3.times { |i| @alt.carousel_media.attach(io: StringIO.new("i#{i}"), filename: "c#{i}.png", content_type: "image/png") }
    @post.update!(feed_alternative: nil, carousel_alternative: @alt)

    assert_difference "SocialPostDelivery.count", 1 do
      SocialPublisher.publish_post(@post)
    end

    @post.reload
    assert @post.posted?
    assert_equal %w[linkedin], @post.social_post_deliveries.map(&:channel)
    assert_equal %w[carousel], @post.social_post_deliveries.map(&:slot)
  end

  test "publishes to meta and linkedin together when both targets are set" do
    @region.update!(linkedin_integration: integrations(:linkedin_social), linkedin_org_id: "999001")
    LinkedinSocialIntegration.any_instance.stubs(:publish_organization_post).returns("urn:li:share:2")

    assert_difference "SocialPostDelivery.count", 3 do
      SocialPublisher.publish_post(@post)
    end

    @post.reload
    assert @post.posted?
    assert_equal %w[facebook instagram linkedin], @post.social_post_deliveries.map(&:channel).sort
  end
end
