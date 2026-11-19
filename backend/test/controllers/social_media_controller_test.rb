require "test_helper"

# Videos only play (and preview) in Safari when the media URL answers byte
# ranges with 206 and full requests carry a Content-Length that Cloudflare can
# cache and slice.
class SocialMediaControllerTest < ActionDispatch::IntegrationTest
  setup do
    post = social_regions(:pakistan).social_posts.create!(post_date: Date.current)
    @alt = post.social_alternatives.create!(source: :generated, position: 0, headline: "H")
    @alt.reel_media.attach(io: StringIO.new("0123456789"), filename: "reel.v2.mp4", content_type: "video/mp4")
    @path = URI(SocialMedia.public_url(@alt.reel_media)).path
  end

  test "full request sends the whole file with a Content-Length" do
    get @path
    assert_response :ok
    assert_equal "10", response.headers["Content-Length"]
    assert_equal "bytes", response.headers["Accept-Ranges"]
    assert_equal "video/mp4", response.media_type
    assert_includes response.headers["Cache-Control"], "public"
    assert_equal "0123456789", response.body
  end

  test "range request gets a 206 slice" do
    get @path, headers: { "Range" => "bytes=2-5" }
    assert_response :partial_content
    assert_equal "bytes 2-5/10", response.headers["Content-Range"]
    assert_equal "2345", response.body
  end

  test "an open range larger than the chunk cap is a 206 of the first chunk" do
    original = ActiveStorage.streaming_chunk_max_size
    ActiveStorage.streaming_chunk_max_size = 4
    begin
      get @path, headers: { "Range" => "bytes=3-" }
    ensure
      ActiveStorage.streaming_chunk_max_size = original
    end
    assert_response :partial_content
    assert_equal "bytes 3-6/10", response.headers["Content-Range"]
    assert_equal "3456", response.body
  end

  test "a tampered signed id is not found" do
    get @path.sub(%r{social_media/[^/]+}, "social_media/nope")
    assert_response :not_found
  end
end
