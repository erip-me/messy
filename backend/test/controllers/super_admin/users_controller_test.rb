require "test_helper"

class SuperAdminUsersControllerTest < ActionDispatch::IntegrationTest
  test "index as super_admin returns users" do
    get "/admin/users", headers: auth_headers(users(:admin)), as: :json

    assert_response :success
    json = JSON.parse(response.body)
    assert json.key?("users")
    assert json.key?("meta")
    assert_kind_of Array, json["users"]
  end

  test "toggle_super_admin toggles flag" do
    user = users(:regular)
    assert_equal false, user.is_super_admin

    post "/admin/users/#{user.id}/toggle_super_admin",
         headers: auth_headers(users(:admin)), as: :json

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal true, json["is_super_admin"]
  end

  test "index as regular user returns 403" do
    get "/admin/users", headers: auth_headers(users(:regular)), as: :json

    assert_response :forbidden
  end
end
