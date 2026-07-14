require "test_helper"

class LinkedinDiscoveryControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:admin)
    @member = users(:regular)
    @integ = integrations(:linkedin_social)
  end

  test "oauth_url returns a consent URL when the server is configured" do
    SocialOauth::Linkedin.stubs(:configured?).returns(true)
    SocialOauth::Linkedin.stubs(:authorize_url).returns("https://www.linkedin.com/oauth/v2/authorization?x=1")

    get "/integrations/#{@integ.id}/linkedin/oauth_url", headers: auth_headers(@admin), as: :json

    assert_response :success
    assert_match %r{linkedin\.com/oauth}, JSON.parse(response.body)["url"]
  end

  test "oauth_url is 422 when LinkedIn OAuth is not configured" do
    SocialOauth::Linkedin.stubs(:configured?).returns(false)

    get "/integrations/#{@integ.id}/linkedin/oauth_url", headers: auth_headers(@admin), as: :json
    assert_response :unprocessable_entity
  end

  test "organizations proxies the integration discovery" do
    LinkedinSocialIntegration.any_instance.stubs(:organizations).returns([{ "id" => "1", "name" => "Acme" }])

    get "/integrations/#{@integ.id}/linkedin/organizations", headers: auth_headers(@admin), as: :json

    assert_response :success
    assert_equal [{ "id" => "1", "name" => "Acme" }], JSON.parse(response.body)
  end

  test "rejects a non-LinkedIn integration" do
    get "/integrations/#{integrations(:meta_social).id}/linkedin/oauth_url",
        headers: auth_headers(@admin), as: :json
    assert_response :unprocessable_entity
  end

  test "members cannot reach discovery" do
    get "/integrations/#{@integ.id}/linkedin/organizations", headers: auth_headers(@member), as: :json
    assert_response :forbidden
  end
end
