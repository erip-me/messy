require "test_helper"

class DeviceTokensControllerTest < ActionDispatch::IntegrationTest
  test "create registers device token" do
    assert_difference "DeviceToken.count", 1 do
      post "/device_tokens",
           params: { email: "john@example.com", token: "new_fcm_token_xyz", platform: "android" },
           headers: api_key_headers(environments(:production)), as: :json
    end

    assert_response :created
    json = JSON.parse(response.body)
    assert_equal "android", json["device_token"]["platform"]
    assert json["device_token"]["active"]
  end

  test "create auto-creates customer if not found" do
    assert_difference ["DeviceToken.count", "Customer.count"], 1 do
      post "/device_tokens",
           params: { email: "brand_new@example.com", token: "new_token_abc", platform: "ios", first_name: "Brand", last_name: "New" },
           headers: api_key_headers(environments(:production)), as: :json
    end

    assert_response :created
    customer = Customer.find_by(email: "brand_new@example.com")
    assert_equal "Brand", customer.first_name
    assert customer.last_seen_at.present?
  end

  test "create requires token email and platform" do
    post "/device_tokens",
         params: { email: "john@example.com" },
         headers: api_key_headers(environments(:production)), as: :json

    assert_response :unprocessable_entity
  end

  test "create removes same token from different customer" do
    existing = device_tokens(:johns_iphone)
    old_id = existing.id

    post "/device_tokens",
         params: { email: "jane@example.com", token: existing.token, platform: "ios" },
         headers: api_key_headers(environments(:production)), as: :json

    assert_response :created
    assert_not DeviceToken.exists?(old_id)
    # New token assigned to jane
    new_token = DeviceToken.find_by(token: existing.token)
    assert_equal customers(:jane).id, new_token.customer_id
  end

  test "destroy deactivates token" do
    token = device_tokens(:johns_iphone)

    delete "/device_tokens/#{token.id}",
           headers: api_key_headers(environments(:production)), as: :json

    assert_response :success
    assert_not token.reload.active
  end

  test "destroy returns 404 for wrong account" do
    delete "/device_tokens/#{device_tokens(:johns_iphone).id}",
           headers: api_key_headers(environments(:other_env)), as: :json

    assert_response :not_found
  end
end
