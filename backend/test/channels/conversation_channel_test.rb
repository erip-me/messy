require "test_helper"

class ConversationChannelTest < ActionCable::Channel::TestCase
  test "subscribes to conversation as operator" do
    user = users(:admin)
    conversation = conversations(:open_chat)

    stub_connection current_user: user, visitor_token: nil, account_id: user.account_id

    subscribe conversation_id: conversation.id

    assert subscription.confirmed?
    assert_has_stream "conversation_#{conversation.id}"
  end

  test "subscribes to conversation as visitor" do
    conversation = conversations(:open_chat)

    stub_connection current_user: nil, visitor_token: conversation.visitor_token, account_id: conversation.account_id

    subscribe conversation_id: conversation.id

    assert subscription.confirmed?
    assert_has_stream "conversation_#{conversation.id}"
  end

  test "rejects subscription for wrong account" do
    user = users(:other_user)
    conversation = conversations(:open_chat) # belongs to acme

    stub_connection current_user: user, visitor_token: nil, account_id: user.account_id

    subscribe conversation_id: conversation.id

    assert subscription.rejected?
  end

  test "rejects subscription for wrong visitor token" do
    conversation = conversations(:open_chat)

    stub_connection current_user: nil, visitor_token: "wrong_token", account_id: conversation.account_id

    subscribe conversation_id: conversation.id

    assert subscription.rejected?
  end
end
