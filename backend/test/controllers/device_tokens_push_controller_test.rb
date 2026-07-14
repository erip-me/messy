require "test_helper"

class DeviceTokensPushControllerTest < ActionDispatch::IntegrationTest
  # --- index ---

  test "index lists active tokens for customer" do
    get "/device_tokens?email=john@example.com",
        headers: api_key_headers(environments(:production))

    assert_response :success
    json = JSON.parse(response.body)
    tokens = json["device_tokens"]
    assert tokens.length >= 3
    platforms = tokens.map { |t| t["platform"] }
    assert_includes platforms, "ios"
    assert_includes platforms, "android"
    assert_includes platforms, "web"
  end

  test "index filters by platform" do
    get "/device_tokens?email=john@example.com&platform=ios",
        headers: api_key_headers(environments(:production))

    assert_response :success
    json = JSON.parse(response.body)
    tokens = json["device_tokens"]
    assert tokens.all? { |t| t["platform"] == "ios" }
  end

  test "index returns empty for unknown customer" do
    get "/device_tokens?email=nobody@example.com",
        headers: api_key_headers(environments(:production))

    assert_response :success
    json = JSON.parse(response.body)
    assert_empty json["device_tokens"]
  end

  test "index requires email" do
    get "/device_tokens",
        headers: api_key_headers(environments(:production))

    assert_response :unprocessable_entity
  end

  # --- create with new fields ---

  test "create accepts device_id app_id and device_name" do
    post "/device_tokens",
         params: {
           email: "john@example.com",
           token: "new_push_token_xyz",
           platform: "ios",
           device_id: "IDFV-1234",
           app_id: "com.example.app",
           device_name: "iPhone 15 Pro"
         },
         headers: api_key_headers(environments(:production)), as: :json

    assert_response :created
    json = JSON.parse(response.body)["device_token"]
    assert_equal "IDFV-1234", json["device_id"]
    assert_equal "com.example.app", json["app_id"]
    assert_equal "iPhone 15 Pro", json["device_name"]
  end

  # --- update ---

  test "update changes device token metadata" do
    token = device_tokens(:johns_iphone)

    patch "/device_tokens/#{token.id}",
          params: { device_name: "Old iPhone" },
          headers: api_key_headers(environments(:production)), as: :json

    assert_response :success
    json = JSON.parse(response.body)["device_token"]
    assert_equal "Old iPhone", json["device_name"]
  end

  test "update can deactivate a token" do
    token = device_tokens(:johns_android)

    patch "/device_tokens/#{token.id}",
          params: { active: false },
          headers: api_key_headers(environments(:production)), as: :json

    assert_response :success
    assert_not token.reload.active
  end

  test "update returns 404 for wrong account" do
    patch "/device_tokens/#{device_tokens(:johns_iphone).id}",
          params: { device_name: "Hacked" },
          headers: api_key_headers(environments(:other_env)), as: :json

    assert_response :not_found
  end

  # --- unregister ---

  test "unregister deactivates by token value" do
    token = device_tokens(:johns_android)

    post "/device_tokens/unregister",
         params: { token: token.token },
         headers: api_key_headers(environments(:production)), as: :json

    assert_response :success
    assert_not token.reload.active
  end

  test "unregister requires token param" do
    post "/device_tokens/unregister",
         headers: api_key_headers(environments(:production)), as: :json

    assert_response :unprocessable_entity
  end

  test "unregister returns 404 for unknown token" do
    post "/device_tokens/unregister",
         params: { token: "nonexistent_token" },
         headers: api_key_headers(environments(:production)), as: :json

    assert_response :not_found
  end

  test "unregister scoped to account" do
    post "/device_tokens/unregister",
         params: { token: device_tokens(:johns_iphone).token },
         headers: api_key_headers(environments(:other_env)), as: :json

    assert_response :not_found
    assert device_tokens(:johns_iphone).reload.active
  end
end
