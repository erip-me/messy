require "test_helper"

class OperatorInboxChannelTest < ActionCable::Channel::TestCase
  test "subscribes as authenticated operator" do
    user = users(:admin)
    stub_connection current_user: user, visitor_token: nil, account_id: user.account_id

    subscribe

    assert subscription.confirmed?
    assert_has_stream "operator_inbox_#{user.account_id}"
  end

  test "rejects subscription without user" do
    stub_connection current_user: nil, visitor_token: "visitor", account_id: 1

    subscribe

    assert subscription.rejected?
  end
end
