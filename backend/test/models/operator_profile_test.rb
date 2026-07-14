require "test_helper"

class OperatorProfileTest < ActiveSupport::TestCase
  test "validates public_name presence" do
    profile = OperatorProfile.new(user: users(:other_user), account: accounts(:other_co))
    assert_not profile.valid?
    assert_includes profile.errors[:public_name], "can't be blank"
  end

  test "validates user_id uniqueness" do
    existing = operator_profiles(:admin_profile)
    duplicate = OperatorProfile.new(
      user: existing.user,
      account: existing.account,
      public_name: "Duplicate"
    )
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:user_id], "has already been taken"
  end

  test "validates max_concurrent_chats positive" do
    profile = operator_profiles(:admin_profile)
    profile.max_concurrent_chats = 0
    assert_not profile.valid?

    profile.max_concurrent_chats = 5
    assert profile.valid?
  end

  test "availability enum values" do
    profile = operator_profiles(:admin_profile)
    assert profile.online?

    profile.availability = :away
    assert profile.away?

    profile.availability = :offline
    assert profile.offline?
  end

  test "currently_online? requires online availability and recent heartbeat" do
    profile = operator_profiles(:admin_profile)
    # admin_profile has heartbeat 30 seconds ago and online availability
    assert profile.currently_online?
  end

  test "currently_online? false when heartbeat stale" do
    profile = operator_profiles(:regular_profile)
    # regular_profile has heartbeat 2 minutes ago (> 90s TTL) and away
    assert_not profile.currently_online?
  end

  test "heartbeat! updates last_heartbeat_at" do
    profile = operator_profiles(:admin_profile)
    old_time = profile.last_heartbeat_at
    profile.heartbeat!
    assert profile.last_heartbeat_at > old_time
  end

  test "available scope returns online with recent heartbeat" do
    available = OperatorProfile.where(account: accounts(:acme)).available
    assert_includes available, operator_profiles(:admin_profile)
    assert_not_includes available, operator_profiles(:regular_profile)
  end

  test "at_capacity? checks open conversation count" do
    profile = operator_profiles(:admin_profile)
    profile.max_concurrent_chats = 10
    assert_not profile.at_capacity?
  end

  test "as_public_json returns expected keys" do
    profile = operator_profiles(:admin_profile)
    json = profile.as_public_json
    assert_equal "Alex Support", json[:name]
    assert_equal "Here to help!", json[:bio]
    assert json[:online]
  end
end
