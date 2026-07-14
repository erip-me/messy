require "test_helper"

class MagicLinksControllerTest < ActionDispatch::IntegrationTest
  test "create creates magic link" do
    headers = { "CONTENT_TYPE" => "application/json" }

    post "/magic_links",
         params: { email: "admin@acme.com" }.to_json,
         headers: headers

    assert_response :success
    json = JSON.parse(response.body)
    assert json["message"].present?
  end

  test "validate with valid token returns user and JWT" do
    user = users(:admin)
    user.generate_magic_link_token!

    get "/magic_links/validate", params: { token: user.magic_link_token }

    assert_response :success
    json = JSON.parse(response.body)
    assert json["token"].present?
    assert_equal user.id, json["user"]["id"]
  end

  test "validate with expired token returns 401" do
    user = users(:admin)
    user.generate_magic_link_token!
    user.update_column(:magic_link_token_expires_at, 1.hour.ago)

    get "/magic_links/validate", params: { token: user.magic_link_token }

    assert_response :unauthorized
  end

  test "logout clears session" do
    delete "/magic_links/logout"

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal "Logged out", json["message"]
  end

  # --- User enumeration / unauthenticated user creation (security) ---

  test "create returns the same generic response for unknown emails" do
    headers = { "CONTENT_TYPE" => "application/json" }

    post "/magic_links", params: { email: "nobody-here@nowhere.test" }.to_json, headers: headers
    unknown_status = response.status
    unknown_body = JSON.parse(response.body)

    post "/magic_links", params: { email: "admin@acme.com" }.to_json, headers: headers
    known_status = response.status
    known_body = JSON.parse(response.body)

    assert_equal known_status, unknown_status, "status must not reveal whether the email exists"
    assert_equal known_body["message"], unknown_body["message"], "message must not reveal existence"
    refute unknown_body.key?("error"), "must not return a distinguishing error for unknown emails"
  end

  test "create does not create a user for an unknown email" do
    headers = { "CONTENT_TYPE" => "application/json" }

    assert_no_difference "User.count" do
      post "/magic_links", params: { email: "brand-new@nowhere.test" }.to_json, headers: headers
    end
  end
end
