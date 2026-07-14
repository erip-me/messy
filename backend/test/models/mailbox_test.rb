require "test_helper"

class MailboxTest < ActiveSupport::TestCase
  test "validates name presence" do
    m = Mailbox.new(account: accounts(:acme), environment: environments(:production), email_address: "x@x.com")
    assert_not m.valid?
    assert_includes m.errors[:name], "can't be blank"
  end

  test "validates email_address uniqueness per account" do
    m = Mailbox.new(account: accounts(:acme), environment: environments(:production),
                    name: "Dup", email_address: mailboxes(:support).email_address, provider: :imap)
    assert_not m.valid?
    assert_includes m.errors[:email_address], "has already been taken"
  end

  test "next_ticket_number! returns incrementing numbers atomically" do
    m = mailboxes(:support)
    first = m.next_ticket_number!
    second = m.next_ticket_number!

    assert_match /^SUP-\d+$/, first
    assert_match /^SUP-\d+$/, second

    first_num = first.split("-").last.to_i
    second_num = second.split("-").last.to_i
    assert_equal 1, second_num - first_num
  end

  test "next_ticket_number! uses # prefix when no ticket_prefix" do
    m = mailboxes(:support)
    m.update!(ticket_prefix: "")
    num = m.next_ticket_number!
    assert_match /^#\d+$/, num
  end

  test "notification_enabled? checks event in notification_events" do
    m = mailboxes(:support)
    assert m.notification_enabled?("ticket_created")
    assert m.notification_enabled?(:ticket_closed)

    m.notification_events["ticket_created"] = false
    assert_not m.notification_enabled?("ticket_created")
  end

  test "from_address returns integration source when available" do
    m = mailboxes(:support)
    integration = stub(source: "noreply@acme.com")
    assert_equal "noreply@acme.com", m.from_address(integration)
  end

  test "from_address falls back to mailbox email_address" do
    m = mailboxes(:support)
    assert_equal "support@acme.com", m.from_address(nil)
  end

  test "active_mailboxes scope" do
    assert_includes Mailbox.active_mailboxes, mailboxes(:support)
  end
end
