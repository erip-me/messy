require "test_helper"

# Covers the workspace (Account) resolution boundary: a caller names a workspace
# with X-Account-Id, and the server honours it only for workspaces they belong to.
class WorkspaceSwitchingTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:regular)          # member of :acme only
    @other = accounts(:other_co)     # a workspace they do NOT belong to
  end

  test "no X-Account-Id falls back to the default workspace" do
    get "/accounts", headers: auth_headers(@user), as: :json
    assert_response :success
    assert_equal accounts(:acme).id, JSON.parse(response.body)["id"]
  end

  test "X-Account-Id for a workspace the user belongs to is honoured" do
    get "/accounts",
        headers: auth_headers(@user).merge("X-Account-Id" => accounts(:acme).id.to_s),
        as: :json
    assert_response :success
    assert_equal accounts(:acme).id, JSON.parse(response.body)["id"]
  end

  test "X-Account-Id for a workspace the user does not belong to is forbidden" do
    get "/accounts",
        headers: auth_headers(@user).merge("X-Account-Id" => @other.id.to_s),
        as: :json
    assert_response :forbidden
    assert_equal "unknown_workspace", JSON.parse(response.body)["code"]
  end

  test "a non-existent X-Account-Id is forbidden, not silently ignored" do
    get "/accounts",
        headers: auth_headers(@user).merge("X-Account-Id" => "0"),
        as: :json
    assert_response :forbidden
  end

  # The pre-membership code fell back to the first environment here, so selecting
  # the wrong workspace silently showed a different one's data.
  test "an environment from another workspace is forbidden, not swapped out" do
    foreign_env = Environment.create!(account: @other, name: "Foreign")

    get "/messages",
        headers: auth_headers(@user).merge("X-Environment-Id" => foreign_env.id.to_s),
        as: :json
    assert_response :forbidden
    assert_equal "unknown_environment", JSON.parse(response.body)["code"]
  end

  test "switching workspace scopes the data returned" do
    AccountMembership.create!(user: @user, account: @other, role: :member)

    get "/accounts",
        headers: auth_headers(@user).merge("X-Account-Id" => @other.id.to_s),
        as: :json
    assert_response :success
    assert_equal @other.id, JSON.parse(response.body)["id"]
  end

  test "admin of one workspace is not automatically admin of another" do
    # Admin in :acme, plain member in :other_co.
    AccountMembership.create!(user: users(:regular), account: @other, role: :member)
    users(:regular).membership_for(accounts(:acme)).update!(role: :admin)

    patch "/accounts/#{accounts(:acme).id}", params: { account: { name: "Renamed" } },
          headers: auth_headers(users(:regular)).merge("X-Account-Id" => accounts(:acme).id.to_s),
          as: :json
    assert_response :success

    patch "/accounts/#{@other.id}", params: { account: { name: "Nope" } },
          headers: auth_headers(users(:regular)).merge("X-Account-Id" => @other.id.to_s),
          as: :json
    assert_response :forbidden
  end

  test "users/me lists every workspace the caller belongs to" do
    AccountMembership.create!(user: @user, account: @other, role: :member)

    get "/users/me", headers: auth_headers(@user), as: :json
    assert_response :success
    ids = JSON.parse(response.body)["workspaces"].map { |w| w["id"] }
    assert_equal [accounts(:acme).id, @other.id].sort, ids.sort
  end

  test "creating a workspace makes the creator its first admin" do
    assert_difference -> { Account.count } => 1, -> { AccountMembership.count } => 1 do
      post "/accounts", params: { name: "Second Client" },
           headers: auth_headers(@user), as: :json
    end
    assert_response :created

    created = Account.find(JSON.parse(response.body)["id"])
    assert_equal "admin", @user.membership_for(created).role
  end
end
