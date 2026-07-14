require "test_helper"

class ConversationAutoAssignerTest < ActiveSupport::TestCase
  setup do
    @account = accounts(:acme)
    @conversation = Conversation.create!(
      account: @account,
      environment: environments(:production),
      visitor_token: "test_auto_assign_token",
      visitor_name: "Test Visitor",
      status: :open
    )
  end

  test "assigns to available operator" do
    user = ConversationAutoAssigner.assign(@conversation)

    assert_not_nil user
    @conversation.reload
    assert_equal user.id, @conversation.assigned_user_id
  end

  test "assigns to operator with fewest open conversations" do
    # admin_profile is online with recent heartbeat
    # Give admin some existing conversations
    3.times do |i|
      Conversation.create!(
        account: @account,
        environment: environments(:production),
        visitor_token: "existing_#{i}",
        visitor_name: "Existing #{i}",
        status: :open,
        assigned_user_id: users(:admin).id
      )
    end

    # Make regular user also available
    profile = operator_profiles(:regular_profile)
    profile.update!(availability: :online, last_heartbeat_at: 10.seconds.ago)

    user = ConversationAutoAssigner.assign(@conversation)

    # Should assign to regular (fewer open conversations)
    assert_equal users(:regular).id, user.id
  end

  test "returns nil when no operators available" do
    # Make all operators unavailable
    OperatorProfile.where(account: @account).update_all(availability: 2) # offline

    user = ConversationAutoAssigner.assign(@conversation)

    assert_nil user
    @conversation.reload
    assert_nil @conversation.assigned_user_id
  end

  test "respects max concurrent chats" do
    profile = operator_profiles(:admin_profile)
    profile.update!(max_concurrent_chats: 1)

    # Admin already has one assigned conversation
    Conversation.create!(
      account: @account,
      environment: environments(:production),
      visitor_token: "existing_cap",
      visitor_name: "Existing",
      status: :open,
      assigned_user_id: users(:admin).id
    )

    # Make regular unavailable
    operator_profiles(:regular_profile).update!(availability: :offline)

    user = ConversationAutoAssigner.assign(@conversation)

    assert_nil user
  end

  test "creates assignment record" do
    assert_difference "ConversationAssignment.count", 1 do
      ConversationAutoAssigner.assign(@conversation)
    end
  end

  test "skips operators with auto_assign false" do
    operator_profiles(:admin_profile).update!(auto_assign: false)

    # regular profile is away, not available
    user = ConversationAutoAssigner.assign(@conversation)

    assert_nil user
  end
end
