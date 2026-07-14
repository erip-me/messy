require "test_helper"

class UsersControllerTest < ActionDispatch::IntegrationTest
  test "index with auth returns account users" do
    get "/users", headers: auth_headers(users(:admin)), as: :json

    assert_response :success
    json = JSON.parse(response.body)
    assert_kind_of Array, json
    emails = json.map { |u| u["email"] }
    assert_includes emails, "admin@acme.com"
    assert_includes emails, "regular@acme.com"
  end

  test "index without auth returns 401" do
    get "/users", as: :json

    assert_response :unauthorized
  end

  test "me returns current user and token" do
    get "/users/me", headers: auth_headers(users(:admin)), as: :json

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal users(:admin).id, json["user"]["id"]
    assert json["token"].present?
  end

  test "create creates user under current account" do
    assert_difference "User.count", 1 do
      post "/users", params: { name: "New User", email: "new@acme.com" },
           headers: auth_headers(users(:admin)), as: :json
    end

    assert_response :created
    json = JSON.parse(response.body)
    assert_equal "New User", json["name"]
    assert_equal users(:admin).account_id, json["account_id"]
  end

  test "update updates user" do
    user = users(:regular)

    patch "/users/#{user.id}", params: { user: { name: "Updated Name" } },
          headers: auth_headers(users(:admin)), as: :json

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal "Updated Name", json["name"]
  end

  test "destroy destroys user" do
    user = users(:regular)

    assert_difference "User.count", -1 do
      delete "/users/#{user.id}", headers: auth_headers(users(:admin)), as: :json
    end

    assert_response :no_content
  end

  # --- Intra-account authorization (security) ---

  test "member cannot create users" do
    assert_no_difference "User.count" do
      post "/users", params: { name: "Sneaky", email: "sneaky@acme.com" },
           headers: auth_headers(users(:regular)), as: :json
    end
    assert_response :forbidden
  end

  test "member cannot delete users" do
    target = users(:admin)
    assert_no_difference "User.count" do
      delete "/users/#{target.id}", headers: auth_headers(users(:regular)), as: :json
    end
    assert_response :forbidden
  end

  test "members can still read the user list" do
    get "/users", headers: auth_headers(users(:regular)), as: :json
    assert_response :success
  end

  # --- Role management ---

  test "invited user defaults to member" do
    post "/users", params: { name: "Member", email: "member@acme.com" },
         headers: auth_headers(users(:admin)), as: :json
    assert_response :created
    assert User.find_by(email: "member@acme.com").member?
  end

  test "admin can invite another admin" do
    post "/users", params: { name: "Boss", email: "boss@acme.com", role: "admin" },
         headers: auth_headers(users(:admin)), as: :json
    assert_response :created
    assert User.find_by(email: "boss@acme.com").admin?
  end

  test "admin can promote a member to admin" do
    patch "/users/#{users(:regular).id}", params: { user: { role: "admin" } },
          headers: auth_headers(users(:admin)), as: :json
    assert_response :success
    assert users(:regular).reload.admin?
  end

  test "cannot demote the last admin" do
    patch "/users/#{users(:admin).id}", params: { user: { role: "member" } },
          headers: auth_headers(users(:admin)), as: :json
    assert_response :unprocessable_entity
    assert users(:admin).reload.account_admin?
  end

  test "can demote an admin when another admin remains" do
    users(:regular).update!(role: :admin)
    patch "/users/#{users(:admin).id}", params: { user: { role: "member" } },
          headers: auth_headers(users(:admin)), as: :json
    assert_response :success
    assert users(:admin).reload.member?
  end
end
