require "test_helper"

class LinkedinSocialIntegrationTest < ActiveSupport::TestCase
  setup { @integ = integrations(:linkedin_social) }

  test "sets kind to social on validation" do
    li = LinkedinSocialIntegration.new(account: accounts(:acme), config: {})
    li.valid?
    assert li.social?
  end

  test "configured? requires an access token" do
    assert @integ.configured?
    @integ.access_token = nil
    assert_not @integ.configured?
  end

  test "organizations maps the acl decoration to id + name and drops undecorated rows" do
    @integ.stubs(:rest_get).returns({
      "elements" => [
        { "organization" => "urn:li:organization:999001", "organization~" => { "id" => 999001, "localizedName" => "Acme" } },
        { "organization" => "urn:li:organization:2" } # no decoration → dropped
      ]
    })
    assert_equal [{ "id" => "999001", "name" => "Acme" }], @integ.organizations
  end

  test "publish_organization_post uploads each image and posts a single-image share" do
    @integ.stubs(:upload_image).returns("urn:li:image:A")
    captured = capture_post_body("urn:li:share:123")

    result = @integ.publish_organization_post(
      org_id: "999001", images: [{ data: "bytes", content_type: "image/png" }], caption: "Hello (world)"
    )

    assert_equal "urn:li:share:123", result
    assert_equal "urn:li:organization:999001", captured[:body]["author"]
    assert_equal({ "id" => "urn:li:image:A" }, captured[:body]["content"]["media"])
    assert_equal "Hello \\(world\\)", captured[:body]["commentary"] # reserved chars escaped
  end

  test "publish_organization_post uses multiImage for more than one image" do
    @integ.stubs(:upload_image).returns("urn:li:image:A", "urn:li:image:B")
    captured = capture_post_body("urn:li:share:9")

    @integ.publish_organization_post(
      org_id: "999001",
      images: [{ data: "a", content_type: "image/png" }, { data: "b", content_type: "image/png" }], caption: "hi"
    )

    assert_equal [{ "id" => "urn:li:image:A" }, { "id" => "urn:li:image:B" }],
                 captured[:body]["content"]["multiImage"]["images"]
  end

  test "publish_organization_post rejects an imageless post" do
    assert_raises(LinkedinSocialIntegration::PublishError) do
      @integ.publish_organization_post(org_id: "999001", images: [], caption: "x")
    end
  end

  test "valid_access_token! skips refresh when the token is fresh" do
    @integ.token_expires_at = 1.hour.from_now.iso8601
    SocialOauth::Linkedin.expects(:refresh).never
    assert_equal "test_linkedin_access_token", @integ.send(:valid_access_token!)
  end

  test "valid_access_token! refreshes an expiring token and persists it" do
    @integ.update!(config: @integ.config.merge("token_expires_at" => 1.minute.ago.iso8601))
    SocialOauth::Linkedin.expects(:refresh).with("test_linkedin_refresh_token")
      .returns("access_token" => "new_tok", "token_expires_at" => 1.hour.from_now.iso8601)

    assert_equal "new_tok", @integ.send(:valid_access_token!)
    assert_equal "new_tok", @integ.reload.access_token
  end

  private

  # Stub the HTTP boundary for create_post and return what the /posts call sent.
  def capture_post_body(post_id)
    captured = {}
    @integ.stubs(:rest_raw_post).with do |url, body|
      captured[:body] = body if url.end_with?("/posts")
      true
    end.returns(fake_response(headers: { "x-restli-id" => post_id }))
    captured
  end

  def fake_response(status: 201, body: "", headers: {})
    Struct.new(:status, :body, :headers) do
      def success?
        status.between?(200, 299)
      end
    end.new(status, body, headers)
  end
end
