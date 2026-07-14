require "test_helper"

class Widget::IdentityControllerTest < ActionDispatch::IntegrationTest
  setup do
    @account = accounts(:acme)
    @visitor_token = "identity_test_#{SecureRandom.hex(8)}"
    @headers = { "X-Widget-Key" => chat_widget_settings(:acme_settings).widget_key, "X-Visitor-Token" => @visitor_token }
  end

  test "identify creates customer with email" do
    assert_difference "Customer.count", 1 do
      post "/widget/v1/identify",
           params: { email: "new_identity@visitor.com", first_name: "New", last_name: "Visitor" },
           headers: @headers,
           as: :json
    end

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal "new_identity@visitor.com", json["customer"]["email"]
    assert_equal "New", json["customer"]["first_name"]
  end

  test "identify merges anonymous customer with existing" do
    anon = Customer.create!(account: @account, anonymous_token: @visitor_token, first_name: "Anon Fox")
    conv = Conversation.create!(
      account: @account,
      environment: environments(:production),
      visitor_token: @visitor_token,
      visitor_name: "Anon Fox",
      customer: anon,
      status: :open
    )

    # Use a unique email not already in fixtures
    unique_email = "merge_test_#{SecureRandom.hex(4)}@example.com"
    existing = Customer.create!(account: @account, email: unique_email, first_name: "Existing")

    post "/widget/v1/identify",
         params: { email: unique_email },
         headers: @headers,
         as: :json

    assert_response :success

    conv.reload
    assert_equal existing.id, conv.customer_id

    assert_nil Customer.find_by(id: anon.id)

    existing.reload
    assert_equal @visitor_token, existing.anonymous_token
  end

  test "identify updates anonymous customer" do
    anon = Customer.create!(account: @account, anonymous_token: @visitor_token, first_name: "Anon")

    post "/widget/v1/identify",
         params: { email: "identified_#{SecureRandom.hex(4)}@example.com", first_name: "Real", last_name: "Name" },
         headers: @headers,
         as: :json

    assert_response :success
    anon.reload
    assert_equal "Real", anon.first_name
    assert_equal "Name", anon.last_name
  end

  test "identify requires email" do
    post "/widget/v1/identify",
         params: { first_name: "No Email" },
         headers: @headers,
         as: :json

    assert_response :unprocessable_entity
  end

  # --- Identity verification (security) ---

  test "rejects identify without a valid HMAC when verification is enabled" do
    chat_widget_settings(:acme_settings).update!(identity_verification_secret: "shhh-secret")

    assert_no_difference "Customer.count" do
      post "/widget/v1/identify",
           params: { email: "victim@example.com" }, # no user_hash
           headers: @headers, as: :json
    end
    assert_response :forbidden

    post "/widget/v1/identify",
         params: { email: "victim@example.com", user_hash: "deadbeef" }, # wrong hash
         headers: @headers, as: :json
    assert_response :forbidden
  end

  test "accepts identify with a valid HMAC when verification is enabled" do
    chat_widget_settings(:acme_settings).update!(identity_verification_secret: "shhh-secret")
    email = "verified_#{SecureRandom.hex(4)}@example.com"
    valid_hash = OpenSSL::HMAC.hexdigest("SHA256", "shhh-secret", email)

    post "/widget/v1/identify",
         params: { email: email, user_hash: valid_hash },
         headers: @headers, as: :json

    assert_response :success
    assert_equal email, JSON.parse(response.body)["customer"]["email"]
  end
end
