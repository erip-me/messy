require "test_helper"

class ConversationMessageTest < ActiveSupport::TestCase
  test "validates content presence for text messages" do
    msg = ConversationMessage.new(
      conversation: conversations(:open_chat),
      account: accounts(:acme),
      sender_type: "Customer",
      message_type: :text
    )
    assert_not msg.valid?
    assert_includes msg.errors[:content], "can't be blank"
  end

  test "validates sender_type inclusion" do
    msg = ConversationMessage.new(
      conversation: conversations(:open_chat),
      account: accounts(:acme),
      sender_type: "Invalid",
      message_type: :text,
      content: "test"
    )
    assert_not msg.valid?
    assert_includes msg.errors[:sender_type], "is not included in the list"
  end

  test "message_type enum values" do
    assert conversation_messages(:visitor_message).text?
    assert conversation_messages(:internal_note).note?
    assert conversation_messages(:system_message).system?
  end

  test "private messages are internal notes" do
    note = conversation_messages(:internal_note)
    assert note.private
    assert note.note?
  end

  test "visible_to_visitor scope excludes private messages" do
    c = conversations(:open_chat)
    visible = c.conversation_messages.visible_to_visitor
    assert_not_includes visible, conversation_messages(:internal_note)
    assert_includes visible, conversation_messages(:visitor_message)
  end

  test "sender_name for User type uses operator profile" do
    msg = conversation_messages(:operator_reply)
    # admin has operator_profile with public_name "Alex Support"
    assert_equal "Alex Support", msg.sender_name
  end

  test "sender_name for Customer type uses visitor name" do
    msg = conversation_messages(:visitor_message)
    assert_equal "Friendly Fox", msg.sender_name
  end

  test "sender_name for System type" do
    msg = conversation_messages(:system_message)
    assert_equal "System", msg.sender_name
  end

  test "as_chat_json returns expected keys" do
    msg = conversation_messages(:visitor_message)
    json = msg.as_chat_json
    assert_equal msg.id, json[:id]
    assert_equal msg.content, json[:content]
    assert_equal "text", json[:message_type]
    assert_equal "Customer", json[:sender_type]
    assert_kind_of Array, json[:attachments]
  end

  test "chronological scope orders by created_at asc" do
    c = conversations(:open_chat)
    messages = c.conversation_messages.chronological
    assert messages.first.created_at <= messages.last.created_at
  end
end
