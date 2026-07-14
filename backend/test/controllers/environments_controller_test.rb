require "test_helper"

class EnvironmentsControllerTest < ActionDispatch::IntegrationTest
  test "index with auth returns environments" do
    get "/environments", headers: auth_headers(users(:admin)), as: :json

    assert_response :success
    json = JSON.parse(response.body)
    assert_kind_of Array, json
    names = json.map { |e| e["name"] }
    assert_includes names, "Production"
  end

  test "index without auth returns 401" do
    get "/environments", as: :json

    assert_response :unauthorized
  end

  test "create creates environment with raw JSON body" do
    headers = auth_headers(users(:admin)).merge("CONTENT_TYPE" => "application/json")

    assert_difference "Environment.count", 1 do
      post "/environments",
           params: { name: "Test Env", tag: "test" }.to_json,
           headers: headers
    end

    assert_response :created
    json = JSON.parse(response.body)
    assert_equal "Test Env", json["name"]
  end

  test "toggle_channel toggles email" do
    env = environments(:production)
    original_value = env.allow_email

    post "/environments/#{env.id}/toggle_channel",
         params: { channel: "email" },
         headers: auth_headers(users(:admin)), as: :json

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal !original_value, json["allow_email"]
  end

  test "toggle_channel with invalid channel returns 400" do
    env = environments(:production)

    post "/environments/#{env.id}/toggle_channel",
         params: { channel: "invalid" },
         headers: auth_headers(users(:admin)), as: :json

    assert_response :bad_request
  end

  test "test with valid email params queues delivery" do
    DeliverMessageJob.stubs(:perform_later)
    env = environments(:production)

    post "/environments/#{env.id}/test",
         params: { channel: "email", to: "test@example.com", subject: "Test", body: "Hello" },
         headers: auth_headers(users(:admin)), as: :json

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal true, json["success"]
    assert json["message_id"].present?
  end

  # --- Intra-account authorization (security) ---

  test "member cannot create or delete environments" do
    assert_no_difference "Environment.count" do
      post "/environments",
           params: { name: "Member Env" }.to_json,
           headers: auth_headers(users(:regular)).merge("CONTENT_TYPE" => "application/json")
    end
    assert_response :forbidden

    delete "/environments/#{environments(:production).id}",
           headers: auth_headers(users(:regular)), as: :json
    assert_response :forbidden
  end

  test "members can still read environments" do
    get "/environments", headers: auth_headers(users(:regular)), as: :json
    assert_response :success
  end

  # --- Secret serialization (security) ---

  test "show masks whatsapp_token but keeps the account's own api_key" do
    env = environments(:production)
    env.update_column(:whatsapp_token, "EAAsecretmetatoken")

    get "/environments/#{env.id}", headers: auth_headers(users(:admin)), as: :json
    json = JSON.parse(response.body)

    assert_no_match(/EAAsecretmetatoken/, response.body, "Meta WhatsApp token leaked")
    assert_equal "[FILTERED]", json["whatsapp_token"]
    # api_key is the tenant's own credential, surfaced for the "copy API key" UI.
    assert json["api_key"].present?, "environment api_key should remain visible to its owner"
  end

  test "updating with filtered whatsapp_token preserves the stored token" do
    env = environments(:production)
    env.update_column(:whatsapp_token, "EAAsecretmetatoken")

    patch "/environments/#{env.id}",
          params: { environment: { name: "Prod Renamed", whatsapp_token: "[FILTERED]" } },
          headers: auth_headers(users(:admin)), as: :json

    assert_response :success
    env.reload
    assert_equal "Prod Renamed", env.name
    assert_equal "EAAsecretmetatoken", env.whatsapp_token, "sentinel must not clobber stored token"
  end
end
