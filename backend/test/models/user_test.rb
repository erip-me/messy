require "test_helper"

class UserTest < ActiveSupport::TestCase
  fixtures :all

  test "validates name presence" do
    user = users(:admin)
    user.name = nil
    assert_not user.valid?
    assert_includes user.errors[:name], "can't be blank"
  end

  test "validates email presence" do
    user = users(:admin)
    user.email = nil
    assert_not user.valid?
    assert_includes user.errors[:email], "can't be blank"
  end

  test "validates email uniqueness" do
    duplicate = User.new(
      account: accounts(:acme),
      name: "Duplicate",
      email: users(:admin).email
    )
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:email], "has already been taken"
  end

  test "validates email format" do
    user = users(:admin)
    user.email = "invalid-email"
    assert_not user.valid?
    assert_includes user.errors[:email], "is invalid"
  end

  test "generate_magic_link_token! sets token and expiry" do
    user = users(:admin)
    assert_nil user.magic_link_token
    assert_nil user.magic_link_token_expires_at

    user.generate_magic_link_token!
    user.reload

    assert_not_nil user.magic_link_token
    assert_not_nil user.magic_link_token_expires_at
    assert user.magic_link_token_expires_at > Time.now
  end

  test "magic_link_token_valid? returns true when not expired" do
    user = users(:admin)
    user.generate_magic_link_token!

    assert user.magic_link_token_valid?
  end

  test "magic_link_token_valid? returns false when expired" do
    user = users(:admin)
    user.generate_magic_link_token!
    user.update_column(:magic_link_token_expires_at, 1.hour.ago)

    assert_not user.magic_link_token_valid?
  end

  test "reset_magic_link_token! clears token" do
    user = users(:admin)
    user.generate_magic_link_token!
    assert_not_nil user.magic_link_token

    user.reset_magic_link_token!
    user.reload

    assert_nil user.magic_link_token
    assert_nil user.magic_link_token_expires_at
  end

  test "super_admins scope returns only super admins" do
    super_admins = User.super_admins
    assert_includes super_admins, users(:admin)
    assert_not_includes super_admins, users(:regular)
  end

  test "regular_users scope returns only regular users" do
    regular = User.regular_users
    assert_includes regular, users(:regular)
    assert_not_includes regular, users(:admin)
  end

  test "email uniqueness is enforced at the database level" do
    # Bypass the model validation to prove the DB unique index also protects
    # against a race between two concurrent signups.
    assert_raises(ActiveRecord::RecordNotUnique) do
      User.insert!({ account_id: accounts(:acme).id, name: "Dup", email: users(:admin).email,
                     role: 0, created_at: Time.current, updated_at: Time.current })
    end
  end
end
