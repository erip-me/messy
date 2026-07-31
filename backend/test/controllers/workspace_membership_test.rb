require "test_helper"

# Covers adding/removing people across workspaces: one User row per person, many
# memberships. The thing that used to be impossible — the same email in two
# workspaces — is the first test here.
class WorkspaceMembershipTest < ActionDispatch::IntegrationTest
  setup do
    @acme = accounts(:acme)
    @other = accounts(:other_co)
    @acme_admin = users(:admin)
    @other_admin = users(:other_user)
  end

  test "inviting an existing email adds a membership instead of a second user" do
    existing = users(:regular) # already in :acme

    assert_no_difference -> { User.count } do
      assert_difference -> { AccountMembership.count } => 1 do
        post "/users", params: { name: "Regular User", email: existing.email },
             headers: auth_headers(@other_admin), as: :json
      end
    end
    assert_response :created
    assert existing.reload.member_of?(@other)
    assert existing.member_of?(@acme), "must keep their original workspace"
  end

  test "the cross-workspace invite does not rotate the existing magic link token" do
    existing = users(:regular)
    existing.generate_magic_link_token!
    token_before = existing.reload.magic_link_token

    post "/users", params: { name: "Regular User", email: existing.email },
         headers: auth_headers(@other_admin), as: :json
    assert_response :created

    assert_equal token_before, existing.reload.magic_link_token,
                 "rotating it would sign them out of the session they're using"
  end

  test "inviting someone already in the workspace is rejected" do
    post "/users", params: { name: "Regular User", email: users(:regular).email },
         headers: auth_headers(@acme_admin), as: :json
    assert_response :unprocessable_entity
  end

  test "invited emails are downcased so magic-link login can find them" do
    post "/users", params: { name: "Mixed Case", email: "MiXeD@Acme.com" },
         headers: auth_headers(@acme_admin), as: :json
    assert_response :created
    assert User.exists?(email: "mixed@acme.com")
  end

  test "removing someone from one workspace keeps their login and other workspaces" do
    user = users(:regular)
    AccountMembership.create!(user: user, account: @other, role: :member)

    assert_no_difference -> { User.count } do
      delete "/users/#{user.id}",
             headers: auth_headers(@other_admin).merge("X-Account-Id" => @other.id.to_s),
             as: :json
    end
    assert_not user.reload.member_of?(@other)
    assert user.member_of?(@acme)
  end

  test "removing someone from their only workspace destroys the user" do
    user = users(:regular)

    assert_difference -> { User.count } => -1 do
      delete "/users/#{user.id}", headers: auth_headers(@acme_admin), as: :json
    end
  end

  test "a user list is scoped to the workspace, not to every workspace" do
    get "/users", headers: auth_headers(@other_admin), as: :json
    assert_response :success
    emails = JSON.parse(response.body).map { |u| u["email"] }
    assert_includes emails, @other_admin.email
    assert_not_includes emails, users(:regular).email
  end

  test "role reported for a user is the role in the workspace being viewed" do
    user = users(:regular) # member in :acme
    AccountMembership.create!(user: user, account: @other, role: :admin)

    get "/users/#{user.id}",
        headers: auth_headers(@other_admin).merge("X-Account-Id" => @other.id.to_s),
        as: :json
    assert_response :success
    assert_equal "admin", JSON.parse(response.body)["role"]

    get "/users/#{user.id}", headers: auth_headers(@acme_admin), as: :json
    assert_response :success
    assert_equal "member", JSON.parse(response.body)["role"]
  end

  test "destroying a workspace rehomes members who belong elsewhere" do
    user = users(:regular)
    AccountMembership.create!(user: user, account: @other, role: :member)
    user.update_column(:account_id, @other.id) # default workspace is the one going away

    @other.destroy!

    # Survives (still a member of :acme) and its default pointer follows.
    assert User.exists?(user.id), "must not delete someone who works elsewhere"
    assert_equal @acme.id, user.reload.account_id
    # :other_user belonged only to the destroyed workspace, so it goes.
    assert_not User.exists?(@other_admin.id)
  end

  test "destroying a workspace destroys members who belong to no other" do
    assert_difference -> { User.count } => -1 do
      @other.destroy!
    end
  end
end
