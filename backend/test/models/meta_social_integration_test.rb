require "test_helper"

class MetaSocialIntegrationTest < ActiveSupport::TestCase
  setup do
    @integ = integrations(:meta_social)
    @integ.stubs(:page_access_token).returns("page-token")
    @integ.stubs(:wait_until_ready)
    @integ.stubs(:sleep) # don't actually wait out the retry backoff
  end

  # Meta rejects media_publish as "not ready" for a moment after the container
  # reports FINISHED. That transient used to leave the whole day failed.
  test "publish_instagram retries a transient not-ready and succeeds" do
    not_ready = MetaSocialIntegration::PublishError.new(
      "Meta error (https://graph.facebook.com/v21.0/1/media_publish): The media is not ready to be published. Please wait a moment."
    )
    seq = sequence("publish")
    @integ.expects(:graph_post).with { |url, _| url.end_with?("/media") }
      .returns({ "id" => "container-1" }).in_sequence(seq)
    @integ.expects(:graph_post).with { |url, _| url.end_with?("/media_publish") }
      .raises(not_ready).in_sequence(seq)
    @integ.expects(:graph_post).with { |url, _| url.end_with?("/media_publish") }
      .returns({ "id" => "ig-99" }).in_sequence(seq)

    assert_equal "ig-99", @integ.publish_instagram(
      ig_user_id: "1", page_id: "2", media_url: "https://x/i.jpg", caption: "c", video: false
    )
  end

  test "publish_instagram gives up after the retry budget" do
    not_ready = MetaSocialIntegration::PublishError.new("The media is not ready to be published.")
    @integ.stubs(:graph_post).with { |url, _| url.end_with?("/media") }.returns({ "id" => "container-1" })
    @integ.expects(:graph_post).with { |url, _| url.end_with?("/media_publish") }
      .raises(not_ready).times(MetaSocialIntegration::PUBLISH_RETRY_ATTEMPTS)

    assert_raises(MetaSocialIntegration::PublishError) do
      @integ.publish_instagram(ig_user_id: "1", page_id: "2", media_url: "https://x/i.jpg", caption: "c", video: false)
    end
  end

  test "publish_instagram does not retry an unrelated Meta error" do
    @integ.stubs(:graph_post).with { |url, _| url.end_with?("/media") }.returns({ "id" => "container-1" })
    @integ.expects(:graph_post).with { |url, _| url.end_with?("/media_publish") }
      .raises(MetaSocialIntegration::PublishError.new("Meta error: Invalid OAuth access token")).once

    assert_raises(MetaSocialIntegration::PublishError) do
      @integ.publish_instagram(ig_user_id: "1", page_id: "2", media_url: "https://x/i.jpg", caption: "c", video: false)
    end
  end

  test "publish_instagram_carousel retries the same transient" do
    not_ready = MetaSocialIntegration::PublishError.new("The media is not ready to be published.")
    seq = sequence("carousel")
    @integ.stubs(:graph_post).with { |url, _| url.end_with?("/media") }.returns({ "id" => "c" })
    @integ.expects(:graph_post).with { |url, _| url.end_with?("/media_publish") }
      .raises(not_ready).in_sequence(seq)
    @integ.expects(:graph_post).with { |url, _| url.end_with?("/media_publish") }
      .returns({ "id" => "ig-carousel-7" }).in_sequence(seq)

    assert_equal "ig-carousel-7", @integ.publish_instagram_carousel(
      ig_user_id: "1", page_id: "2", media_urls: %w[https://x/a.jpg https://x/b.jpg], caption: "c"
    )
  end
end
