require "test_helper"

class AutoCloseConversationsJobTest < ActiveSupport::TestCase
  test "closes stale conversations" do
    settings = chat_widget_settings(:acme_settings)
    settings.update!(auto_close_hours: 1)

    conv = Conversation.create!(
      account: accounts(:acme),
      environment: environments(:production),
      visitor_token: "stale_token",
      visitor_name: "Stale",
      status: :open,
      last_message_at: 2.hours.ago
    )

    AutoCloseConversationsJob.perform_now

    conv.reload
    assert conv.closed?
    assert conv.resolved_at.present?
    assert_equal "This conversation was automatically closed due to inactivity.",
                 conv.conversation_messages.last.content
  end

  test "does not close recent conversations" do
    conv = conversations(:open_chat)
    original_status = conv.status

    AutoCloseConversationsJob.perform_now

    conv.reload
    assert_equal original_status, conv.status
  end

  test "respects per-account auto_close_hours" do
    settings = chat_widget_settings(:acme_settings)
    settings.update!(auto_close_hours: 48)

    conv = Conversation.create!(
      account: accounts(:acme),
      environment: environments(:production),
      visitor_token: "recent_enough",
      visitor_name: "Recent",
      status: :open,
      last_message_at: 24.hours.ago
    )

    AutoCloseConversationsJob.perform_now

    conv.reload
    assert conv.open? # 24h < 48h, should not close
  end
end
