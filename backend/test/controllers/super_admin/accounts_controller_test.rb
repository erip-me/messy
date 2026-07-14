require "test_helper"

class SuperAdminAccountsControllerTest < ActionDispatch::IntegrationTest
  test "index as super_admin returns accounts" do
    get "/admin/accounts", headers: auth_headers(users(:admin)), as: :json

    assert_response :success
    json = JSON.parse(response.body)
    assert json.key?("accounts")
    assert json.key?("meta")
    assert_kind_of Array, json["accounts"]
  end

  test "index as regular user returns 403" do
    get "/admin/accounts", headers: auth_headers(users(:regular)), as: :json

    assert_response :forbidden
  end

  test "create creates account" do
    assert_difference "Account.count", 1 do
      post "/admin/accounts",
           params: { account: { name: "New Admin Account", plan: "trial" } },
           headers: auth_headers(users(:admin)), as: :json
    end

    assert_response :created
    json = JSON.parse(response.body)
    assert_equal "New Admin Account", json["name"]
  end

  test "destroy destroys account" do
    account = accounts(:other_co)

    assert_difference "Account.count", -1 do
      delete "/admin/accounts/#{account.id}",
             headers: auth_headers(users(:admin)), as: :json
    end

    assert_response :no_content
  end
end
