require "test_helper"

class ConversationReadCursorTest < ActiveSupport::TestCase
  test "validates reader_type inclusion" do
    cursor = ConversationReadCursor.new(
      conversation: conversations(:open_chat),
      reader_type: "invalid"
    )
    assert_not cursor.valid?
    assert_includes cursor.errors[:reader_type], "is not included in the list"
  end

  test "validates uniqueness of conversation + reader_type + reader_id" do
    existing = conversation_read_cursors(:admin_open_chat)
    duplicate = ConversationReadCursor.new(
      conversation: existing.conversation,
      reader_type: existing.reader_type,
      reader_id: existing.reader_id
    )
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:conversation_id], "has already been taken"
  end

  test "visitor cursor has nil reader_id" do
    cursor = conversation_read_cursors(:visitor_open_chat)
    assert_equal "Visitor", cursor.reader_type
    assert_nil cursor.reader_id
  end

  test "belongs to last_read_message" do
    cursor = conversation_read_cursors(:admin_open_chat)
    assert_equal conversation_messages(:visitor_message), cursor.last_read_message
  end
end
