require "test_helper"

class EmailThreadTest < ActiveSupport::TestCase
  test "validates ticket_number uniqueness per account" do
    et = EmailThread.new(
      account: accounts(:acme), mailbox: mailboxes(:support),
      conversation: conversations(:open_chat),
      ticket_number: "SUP-1001", from_email: "test@test.com"
    )
    assert_not et.valid?
    assert_includes et.errors[:ticket_number], "has already been taken"
  end

  test "validates conversation_id uniqueness" do
    et = EmailThread.new(
      account: accounts(:acme), mailbox: mailboxes(:support),
      conversation: conversations(:email_ticket),
      ticket_number: "SUP-9999", from_email: "test@test.com"
    )
    assert_not et.valid?
    assert_includes et.errors[:conversation_id], "has already been taken"
  end

  test "requester_and_cc returns from_email plus cc list" do
    et = email_threads(:billing_ticket)
    result = et.requester_and_cc
    assert_includes result, "sarah@customer.com"
    assert_includes result, "accounting@customer.com"
    assert_equal 2, result.length
  end

  test "requester_and_cc deduplicates" do
    et = email_threads(:billing_ticket)
    et.cc_list = ["sarah@customer.com"]
    result = et.requester_and_cc
    assert_equal 1, result.length
  end

  test "apply_threading_headers! sets In-Reply-To and References" do
    et = email_threads(:billing_ticket)
    conv = et.conversation

    # Create a message with an email detail to thread against
    msg = conv.conversation_messages.create!(
      account: accounts(:acme), sender_type: "Customer", message_type: :text, content: "test"
    )
    EmailMessageDetail.create!(
      conversation_message: msg, message_id_header: "<abc123@customer.com>",
      from_email: "sarah@customer.com", to_email: "support@acme.com"
    )

    mail = Mail.new
    et.apply_threading_headers!(mail)

    assert_equal "abc123@customer.com", mail.in_reply_to
    assert_includes mail.references.to_s, "abc123@customer.com"
  end
end
