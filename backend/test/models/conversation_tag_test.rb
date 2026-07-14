require "test_helper"

class ConversationTagTest < ActiveSupport::TestCase
  test "validates name presence" do
    tag = ConversationTag.new(account: accounts(:acme))
    assert_not tag.valid?
    assert_includes tag.errors[:name], "can't be blank"
  end

  test "validates name uniqueness per account" do
    existing = conversation_tags(:help_tag)
    duplicate = ConversationTag.new(account: existing.account, name: existing.name)
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:name], "has already been taken"
  end

  test "same name allowed on different accounts" do
    tag = ConversationTag.new(account: accounts(:other_co), name: "I need help")
    assert tag.valid?
  end


  test "quick_replies scope returns is_quick_reply tags ordered" do
    quick = ConversationTag.where(account: accounts(:acme)).quick_replies
    assert_includes quick, conversation_tags(:help_tag)
    assert_includes quick, conversation_tags(:pricing_tag)
    assert_not_includes quick, conversation_tags(:bug_tag)
  end

  test "ordered scope sorts by sort_order" do
    tags = ConversationTag.where(account: accounts(:acme)).ordered
    assert tags.first.sort_order <= tags.last.sort_order
  end

  test "has many conversations through taggings" do
    tag = conversation_tags(:pricing_tag)
    assert_includes tag.conversations, conversations(:open_chat)
  end
end
