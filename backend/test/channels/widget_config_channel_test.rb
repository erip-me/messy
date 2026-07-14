require "test_helper"

class WidgetConfigChannelTest < ActionCable::Channel::TestCase
  test "subscribes with account_id" do
    account = accounts(:acme)
    stub_connection current_user: nil, visitor_token: "visitor", account_id: account.id

    subscribe

    assert subscription.confirmed?
    assert_has_stream "widget_config_#{account.id}"
  end

  test "rejects subscription without account_id" do
    stub_connection current_user: nil, visitor_token: "visitor", account_id: nil

    subscribe

    assert subscription.rejected?
  end
end
