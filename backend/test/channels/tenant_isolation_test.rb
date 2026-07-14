require "test_helper"

# =============================================================================
# ActionCable Tenant Isolation Tests
#
# These tests verify that WebSocket channels enforce strict multi-tenant
# data isolation. The core security model:
#
#   - Operators authenticate via JWT -> account_id derived from current_user
#   - Widget visitors authenticate via widget_key -> account_id derived from
#     the ChatWidgetSettings lookup, never from bare params
#   - No channel should ever accept an unverified account_id from params
# =============================================================================

module ApplicationCable
  class ConnectionTenantIsolationTest < ActionCable::Connection::TestCase
    tests ApplicationCable::Connection

    test "rejects connection with only bare account_id (no JWT, no widget_key)" do
      assert_reject_connection do
        connect params: { account_id: accounts(:acme).id }
      end
    end

    test "rejects connection with bare account_id and visitor_token but no widget_key" do
      assert_reject_connection do
        connect params: { visitor_token: "some_token", account_id: accounts(:acme).id }
      end
    end

    test "connects with valid JWT token" do
      user = users(:admin)
      token = JWT.encode({ id: user.id, exp: 24.hours.from_now.to_i }, Rails.application.secret_key_base)

      connect params: { token: token }

      assert_equal user.id, connection.current_user.id
      assert_equal user.account_id, connection.account_id
    end

    test "connects with valid widget_key and visitor_token" do
      widget = chat_widget_settings(:acme_settings)

      connect params: { widget_key: widget.widget_key, visitor_token: "visitor_abc" }

      assert_equal widget.account_id, connection.account_id
      assert_equal "visitor_abc", connection.visitor_token
      assert_nil connection.current_user
    end

    test "rejects connection with invalid widget_key" do
      assert_reject_connection do
        connect params: { widget_key: "nonexistent_key", visitor_token: "visitor_abc" }
      end
    end

    test "rejects connection with widget_key but no visitor_token" do
      widget = chat_widget_settings(:acme_settings)

      assert_reject_connection do
        connect params: { widget_key: widget.widget_key }
      end
    end

    test "account_id is always derived from widget_key, not params" do
      acme_widget = chat_widget_settings(:acme_settings)
      other_account = accounts(:other_co)

      # Attacker passes other_co's account_id but acme's widget_key
      connect params: {
        widget_key: acme_widget.widget_key,
        visitor_token: "attacker_token",
        account_id: other_account.id
      }

      # account_id must come from the widget_key lookup, not from params
      assert_equal acme_widget.account_id, connection.account_id
      assert_not_equal other_account.id, connection.account_id
    end

    test "rejects connection with expired JWT and no widget_key" do
      user = users(:admin)
      token = JWT.encode({ id: user.id, exp: 1.hour.ago.to_i }, Rails.application.secret_key_base)

      assert_reject_connection do
        connect params: { token: token }
      end
    end
  end
end

class MessagesChannelTenantIsolationTest < ActionCable::Channel::TestCase
  tests MessagesChannel

  test "rejects subscription without current_user" do
    stub_connection current_user: nil, visitor_token: "visitor", account_id: accounts(:acme).id

    subscribe

    assert subscription.rejected?
  end

  test "operator subscribes to own account messages" do
    user = users(:admin)
    stub_connection current_user: user, visitor_token: nil, account_id: user.account_id

    subscribe

    assert subscription.confirmed?
    assert_has_stream "messages_channel_#{user.account_id}"
  end

  test "streams from current_user account_id regardless of params" do
    user = users(:admin) # acme account
    other = accounts(:other_co)
    stub_connection current_user: user, visitor_token: nil, account_id: user.account_id

    # The channel ignores params and uses current_user.account_id
    subscribe

    assert subscription.confirmed?
    assert_has_stream "messages_channel_#{user.account_id}"
  end

  test "visitor cannot subscribe to messages channel" do
    stub_connection current_user: nil, visitor_token: "visitor_token", account_id: accounts(:acme).id

    subscribe

    assert subscription.rejected?
  end
end

class WidgetConfigChannelTenantIsolationTest < ActionCable::Channel::TestCase
  tests WidgetConfigChannel

  test "rejects subscription without account_id" do
    stub_connection current_user: nil, visitor_token: "visitor", account_id: nil

    subscribe

    assert subscription.rejected?
  end

  test "subscribes with valid account_id from widget_key" do
    acme = accounts(:acme)
    stub_connection current_user: nil, visitor_token: "visitor", account_id: acme.id

    subscribe

    assert subscription.confirmed?
    assert_has_stream "widget_config_#{acme.id}"
  end

  test "operator subscribes to own account config" do
    user = users(:admin)
    stub_connection current_user: user, visitor_token: nil, account_id: user.account_id

    subscribe

    assert subscription.confirmed?
    assert_has_stream "widget_config_#{user.account_id}"
  end
end

class VisitorPresenceChannelTenantIsolationTest < ActionCable::Channel::TestCase
  tests VisitorPresenceChannel

  test "rejects subscription without visitor_token" do
    stub_connection current_user: nil, visitor_token: nil, account_id: accounts(:acme).id

    subscribe

    assert subscription.rejected?
  end

  test "rejects subscription without account_id" do
    stub_connection current_user: nil, visitor_token: "visitor_abc", account_id: nil

    subscribe

    assert subscription.rejected?
  end

  test "subscribes with valid visitor_token and account_id" do
    acme = accounts(:acme)
    stub_connection current_user: nil, visitor_token: "visitor_token_abc123", account_id: acme.id

    subscribe

    assert subscription.confirmed?
    assert_has_stream "visitor_presence_#{acme.id}"
  end

  test "presence updates are scoped to account and visitor_token" do
    acme = accounts(:acme)
    visitor_token = "visitor_token_abc123"

    # Set up customer in acme with matching token
    customer = customers(:john)
    customer.update_columns(anonymous_token: visitor_token, online: false)

    # Set up customer in other_co with same token (simulating collision)
    other_customer = customers(:other_customer)
    other_customer.update_columns(anonymous_token: visitor_token, online: false)

    stub_connection current_user: nil, visitor_token: visitor_token, account_id: acme.id
    subscribe

    # Only acme's customer should be marked online
    customer.reload
    other_customer.reload
    assert customer.online
    assert_not other_customer.online
  end
end

class ConversationChannelTenantIsolationTest < ActionCable::Channel::TestCase
  tests ConversationChannel

  test "operator cannot subscribe to other account conversation" do
    user = users(:other_user) # other_co account
    conversation = conversations(:open_chat) # acme account

    stub_connection current_user: user, visitor_token: nil, account_id: user.account_id

    subscribe conversation_id: conversation.id

    assert subscription.rejected?
  end

  test "operator subscribes to own account conversation" do
    user = users(:admin)
    conversation = conversations(:open_chat)

    stub_connection current_user: user, visitor_token: nil, account_id: user.account_id

    subscribe conversation_id: conversation.id

    assert subscription.confirmed?
    assert_has_stream "conversation_#{conversation.id}"
  end

  test "visitor subscribes to own conversation" do
    conversation = conversations(:open_chat)
    acme = accounts(:acme)

    stub_connection current_user: nil, visitor_token: conversation.visitor_token, account_id: acme.id

    subscribe conversation_id: conversation.id

    assert subscription.confirmed?
    assert_has_stream "conversation_#{conversation.id}"
  end

  test "visitor cannot subscribe to other account conversation even with matching visitor_token" do
    conversation = conversations(:open_chat) # acme
    other = accounts(:other_co)

    # Attacker connected through other_co's widget but knows acme's conversation ID
    stub_connection current_user: nil, visitor_token: conversation.visitor_token, account_id: other.id

    subscribe conversation_id: conversation.id

    assert subscription.rejected?
  end

  test "visitor with wrong token cannot subscribe to conversation" do
    conversation = conversations(:open_chat)
    acme = accounts(:acme)

    stub_connection current_user: nil, visitor_token: "wrong_token", account_id: acme.id

    subscribe conversation_id: conversation.id

    assert subscription.rejected?
  end
end
