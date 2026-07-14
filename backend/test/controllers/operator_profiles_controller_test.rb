require "test_helper"

class OperatorProfilesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:admin)
    @headers = auth_headers(@user)
  end

  test "show returns operator profile" do
    get "/operator_profile", headers: @headers

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal "Alex Support", json["operator_profile"]["public_name"]
  end

  test "show returns nil for user without profile" do
    other_user = users(:other_user)
    get "/operator_profile", headers: auth_headers(other_user)

    assert_response :success
    json = JSON.parse(response.body)
    assert_nil json["operator_profile"]
  end

  test "update creates profile if not exists" do
    other_user = users(:other_user)
    patch "/operator_profile",
          params: { public_name: "New Support Agent", bio: "Hello!" },
          headers: auth_headers(other_user),
          as: :json

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal "New Support Agent", json["operator_profile"]["public_name"]
  end

  test "update modifies existing profile" do
    patch "/operator_profile",
          params: { public_name: "Updated Name", availability: "away" },
          headers: @headers,
          as: :json

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal "Updated Name", json["operator_profile"]["public_name"]
    assert_equal "away", json["operator_profile"]["availability"]
  end
end
