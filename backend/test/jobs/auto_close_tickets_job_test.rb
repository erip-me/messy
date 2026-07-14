require "test_helper"

class AutoCloseTicketsJobTest < ActiveSupport::TestCase
  test "closes stale email tickets past auto_close_days" do
    mailbox = mailboxes(:support)
    mailbox.update!(auto_close_days: 3)

    conv = conversations(:email_ticket)
    conv.update!(last_message_at: 5.days.ago, status: :open)

    AutoCloseTicketsJob.perform_now

    conv.reload
    assert_equal "closed", conv.status
    assert_not_nil conv.resolved_at

    system_msg = conv.conversation_messages.where(sender_type: "System").last
    assert_includes system_msg.content, "automatically closed"
  end

  test "does not close tickets within auto_close_days" do
    mailbox = mailboxes(:support)
    mailbox.update!(auto_close_days: 7)

    conv = conversations(:email_ticket)
    conv.update!(last_message_at: 2.days.ago, status: :open)

    AutoCloseTicketsJob.perform_now

    conv.reload
    assert_equal "open", conv.status
  end

  test "does not close tickets when auto_close_days is nil" do
    mailbox = mailboxes(:support)
    mailbox.update!(auto_close_days: nil)

    conv = conversations(:email_ticket)
    conv.update!(last_message_at: 30.days.ago, status: :open)

    AutoCloseTicketsJob.perform_now

    conv.reload
    assert_equal "open", conv.status
  end
end
