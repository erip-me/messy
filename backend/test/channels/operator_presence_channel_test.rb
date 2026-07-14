require "test_helper"

class OperatorPresenceChannelTest < ActionCable::Channel::TestCase
  test "subscribes as authenticated operator" do
    user = users(:admin)
    stub_connection current_user: user, visitor_token: nil, account_id: user.account_id

    subscribe

    assert subscription.confirmed?
    assert_has_stream "operator_presence_#{user.account_id}"
  end

  test "rejects subscription without user" do
    stub_connection current_user: nil, visitor_token: "visitor", account_id: 1

    subscribe

    assert subscription.rejected?
  end

  test "heartbeat updates last_heartbeat_at" do
    user = users(:admin)
    profile = operator_profiles(:admin_profile)
    stub_connection current_user: user, visitor_token: nil, account_id: user.account_id

    subscribe

    old_time = profile.last_heartbeat_at
    perform :heartbeat
    profile.reload
    assert profile.last_heartbeat_at >= old_time
  end
end
