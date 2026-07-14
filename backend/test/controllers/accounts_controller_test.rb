require "test_helper"

class AccountsControllerTest < ActionDispatch::IntegrationTest
  test "index returns current user account" do
    get "/accounts", headers: auth_headers(users(:admin)), as: :json

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal accounts(:acme).name, json["name"]
  end

  test "index requires authentication" do
    get "/accounts", as: :json

    assert_response :unauthorized
  end

  test "show returns current user account" do
    account = accounts(:acme)

    get "/accounts/#{account.id}", headers: auth_headers(users(:admin)), as: :json

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal account.name, json["name"]
  end

  test "update updates account" do
    account = accounts(:acme)

    patch "/accounts/#{account.id}",
      params: { account: { name: "Acme Updated" } },
      headers: auth_headers(users(:admin)),
      as: :json

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal "Acme Updated", json["name"]
  end

  test "update with blank name returns 422" do
    account = accounts(:acme)

    patch "/accounts/#{account.id}",
      params: { account: { name: "" } },
      headers: auth_headers(users(:admin)),
      as: :json

    assert_response :unprocessable_entity
  end

  test "update requires authentication" do
    account = accounts(:acme)

    patch "/accounts/#{account.id}",
      params: { account: { name: "Hacked" } },
      as: :json

    assert_response :unauthorized
  end

  test "member cannot update account settings" do
    account = accounts(:acme)

    patch "/accounts/#{account.id}",
      params: { account: { name: "Member Renamed" } },
      headers: auth_headers(users(:regular)),
      as: :json

    assert_response :forbidden
    assert_equal "Acme Corp", account.reload.name
  end
end
