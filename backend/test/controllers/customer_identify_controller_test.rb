require "test_helper"

class CustomerIdentifyControllerTest < ActionDispatch::IntegrationTest
  test "identify creates new customer" do
    assert_difference "Customer.count", 1 do
      post "/customers/identify",
           params: { email: "new_person@example.com", first_name: "New", last_name: "Person" },
           headers: api_key_headers(environments(:production)), as: :json
    end

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal "new_person@example.com", json["customer"]["email"]
    assert_equal "New", json["customer"]["first_name"]
    assert json["customer"]["last_seen_at"].present?
  end

  test "identify updates existing customer" do
    existing = customers(:john)

    assert_no_difference "Customer.count" do
      post "/customers/identify",
           params: { email: existing.email, first_name: "Johnny", custom_attributes: { vip: "true" } },
           headers: api_key_headers(environments(:production)), as: :json
    end

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal existing.id, json["customer"]["id"]
    assert_equal "Johnny", json["customer"]["first_name"]
    assert_equal "true", json["customer"]["custom_attributes"]["vip"]
    # Existing attributes preserved
    assert_equal "buyer", json["customer"]["custom_attributes"]["role"]
  end

  test "identify creates customer activity" do
    assert_difference "CustomerActivity.count", 1 do
      post "/customers/identify",
           params: { email: "john@example.com" },
           headers: api_key_headers(environments(:production)), as: :json
    end

    assert_response :success
  end

  test "identify requires email" do
    post "/customers/identify",
         params: { first_name: "No Email" },
         headers: api_key_headers(environments(:production)), as: :json

    assert_response :unprocessable_entity
  end

  test "identify scopes to account" do
    # john@example.com exists on both accounts
    post "/customers/identify",
         params: { email: "john@example.com", first_name: "Updated" },
         headers: api_key_headers(environments(:other_env)), as: :json

    assert_response :success
    json = JSON.parse(response.body)
    # Should update the other_co customer, not acme's
    other = Customer.where(account: accounts(:other_co), email: "john@example.com").first
    assert_equal "Updated", other.first_name
    # Acme's customer unchanged
    assert_equal "John", customers(:john).reload.first_name
  end
end
