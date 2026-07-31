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

  # `account.users` is a has_many :through, so it can't build the User. The
  # existing create test passes no first_user, which is how that broke unnoticed.
  test "create with a first_user creates the user and its membership" do
    assert_difference -> { Account.count } => 1, -> { User.count } => 1,
                      -> { AccountMembership.count } => 1 do
      post "/admin/accounts",
           params: { account: { name: "With First User", plan: "trial" },
                     first_user: { name: "First User", email: "first@withfirstuser.com" } },
           headers: auth_headers(users(:admin)), as: :json
    end

    assert_response :created
    account = Account.find_by!(name: "With First User")
    user    = User.find_by!(email: "first@withfirstuser.com")
    assert_equal account.id, user.account_id, "default workspace must be set"
    assert user.member_of?(account), "membership must be granted"
    assert_includes account.users, user
    # Sole occupant of a brand new workspace — as a member they could not invite
    # anyone or manage environments, leaving it unadministrable.
    assert_equal "admin", user.membership_for(account).role
    assert user.account_admin?(account)
  end

  test "create rolls the account back when the first_user is invalid" do
    assert_no_difference -> { Account.count } do
      post "/admin/accounts",
           params: { account: { name: "Orphan Account", plan: "trial" },
                     first_user: { name: "Dupe", email: users(:regular).email } },
           headers: auth_headers(users(:admin)), as: :json
    end

    assert_response :unprocessable_entity
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
