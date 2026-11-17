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

  test "admin uploads a workspace logo and it shows in the switcher list" do
    account = accounts(:acme)

    patch "/accounts/#{account.id}/logo",
      params: { logo: fixture_file_upload("logo.png", "image/png") },
      headers: auth_headers(users(:admin))

    assert_response :success
    assert JSON.parse(response.body)["logo_url"].present?
    assert account.reload.logo.attached?

    get "/users/me", headers: auth_headers(users(:admin)), as: :json
    row = JSON.parse(response.body)["workspaces"].find { |w| w["id"] == account.id }
    assert row["avatar_url"].present?

    delete "/accounts/#{account.id}/logo", headers: auth_headers(users(:admin))
    assert_response :success
    assert_nil JSON.parse(response.body)["logo_url"]
  end

  test "logo rejects non-raster uploads" do
    account = accounts(:acme)

    patch "/accounts/#{account.id}/logo",
      params: { logo: Rack::Test::UploadedFile.new(StringIO.new("<svg/>"), "image/svg+xml", original_filename: "x.svg") },
      headers: auth_headers(users(:admin))

    assert_response :unprocessable_entity
    assert_not account.reload.logo.attached?
  end

  test "member cannot change the workspace logo" do
    account = accounts(:acme)

    patch "/accounts/#{account.id}/logo",
      params: { logo: fixture_file_upload("logo.png", "image/png") },
      headers: auth_headers(users(:regular))

    assert_response :forbidden
    assert_not account.reload.logo.attached?
  end
end
