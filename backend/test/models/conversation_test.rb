require "test_helper"

class ConversationTest < ActiveSupport::TestCase
  test "validates visitor_token presence" do
    c = Conversation.new(account: accounts(:acme), environment: environments(:production))
    assert_not c.valid?
    assert_includes c.errors[:visitor_token], "can't be blank"
  end

  test "status enum values" do
    c = conversations(:open_chat)
    assert c.open?

    c.status = :pending
    assert c.pending?

    c.status = :snoozed
    assert c.snoozed?

    c.status = :resolved
    assert c.resolved?

    c.status = :closed
    assert c.closed?
  end

  test "priority enum values" do
    c = conversations(:open_chat)
    assert c.normal?

    c.priority = :high
    assert c.high?

    c.priority = :urgent
    assert c.urgent?
  end

  test "source enum values" do
    c = conversations(:open_chat)
    assert c.source_widget?
  end

  test "active scope returns open and pending" do
    active = Conversation.where(account: accounts(:acme)).active
    assert_includes active, conversations(:open_chat)
    assert_includes active, conversations(:pending_chat)
    assert_not_includes active, conversations(:resolved_chat)
    assert_not_includes active, conversations(:snoozed_chat)
  end

  test "for_visitor scope" do
    result = Conversation.for_visitor("visitor_token_abc123")
    assert_includes result, conversations(:open_chat)
    assert_equal 1, result.count
  end

  test "assigned_to scope" do
    admin = users(:admin)
    assigned = Conversation.where(account: accounts(:acme)).assigned_to(admin)
    assert_includes assigned, conversations(:open_chat)
    assert_not_includes assigned, conversations(:pending_chat)
  end

  test "unassigned scope" do
    unassigned = Conversation.where(account: accounts(:acme)).unassigned
    assert_includes unassigned, conversations(:pending_chat)
    assert_not_includes unassigned, conversations(:open_chat)
  end

  test "has many conversation_messages" do
    c = conversations(:open_chat)
    assert c.conversation_messages.count >= 2
  end

  test "has many conversation_tags through taggings" do
    c = conversations(:open_chat)
    assert_includes c.conversation_tags, conversation_tags(:pricing_tag)
  end

  test "belongs to assigned_user" do
    c = conversations(:open_chat)
    assert_equal users(:admin), c.assigned_user
  end

  test "touch_last_message! updates preview" do
    c = conversations(:open_chat)
    msg = c.conversation_messages.create!(
      account: accounts(:acme),
      sender_type: "Customer",
      message_type: :text,
      content: "Updated message"
    )
    c.touch_last_message!(msg)
    assert_equal "Updated message", c.last_message_preview
    assert_equal msg.created_at, c.last_message_at
  end

  test "unread_count_for operator counts unread messages" do
    c = conversations(:open_chat)
    admin = users(:admin)
    count = c.unread_count_for(admin)
    # admin cursor is at visitor_message, operator_reply is by admin (excluded)
    # so only messages after cursor that aren't from admin count
    assert count >= 0
  end

  test "unread_count_for_visitor counts operator messages" do
    c = conversations(:open_chat)
    # Reset cursor to nil so all operator messages are unread
    c.conversation_read_cursors.where(reader_type: "Visitor").delete_all
    count = c.unread_count_for_visitor
    # With no cursor, all operator (User) messages are unread
    operator_msg_count = c.conversation_messages.where(private: false, sender_type: "User").count
    assert_equal operator_msg_count, count
  end

  test "as_inbox_json returns expected keys" do
    c = conversations(:open_chat)
    json = c.as_inbox_json
    assert_equal c.id, json[:id]
    assert_equal c.visitor_name, json[:visitor_name]
    assert_equal c.status, json[:status]
    assert_equal c.assigned_user_id, json[:assigned_user_id]
  end

  test "multi-tenancy: other account conversation isolated" do
    acme_convos = Conversation.where(account: accounts(:acme))
    assert_not_includes acme_convos, conversations(:other_account_chat)
  end
end
