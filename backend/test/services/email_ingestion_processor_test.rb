require "test_helper"

class EmailIngestionProcessorTest < ActiveSupport::TestCase
  setup do
    @mailbox = mailboxes(:support)
    @account = accounts(:acme)
  end

  def build_mail(from: "sender@example.com", to: "support@acme.com", subject: "Test subject", body: "Test body", message_id: nil)
    Mail.new do |m|
      m.from    from
      m.to      to
      m.subject subject
      m.body    body
      m.message_id = message_id || "<#{SecureRandom.hex(16)}@example.com>"
    end
  end

  test "creates new conversation and email thread from fresh email" do
    mail = build_mail(from: "newcustomer@example.com", subject: "Help with my account")

    assert_difference ["Conversation.count", "EmailThread.count", "ConversationMessage.count", "EmailMessageDetail.count"], 1 do
      EmailIngestion::Processor.new(@mailbox, mail, provider_uid: "uid_1").process!
    end

    conv = Conversation.last
    assert_equal "email", conv.source
    assert_equal "Help with my account", conv.subject
    assert_match /^SUP-\d+$/, conv.ticket_number
    assert_equal "newcustomer@example.com", conv.visitor_email

    thread = conv.email_thread
    assert_equal "newcustomer@example.com", thread.from_email
    assert_equal @mailbox, thread.mailbox
  end

  test "threads reply into existing conversation via In-Reply-To" do
    # Create initial message with a known message ID
    existing_conv = conversations(:email_ticket)
    msg = existing_conv.conversation_messages.create!(
      account: @account, sender_type: "User", message_type: :text, content: "We'll look into it"
    )
    detail = EmailMessageDetail.create!(
      conversation_message: msg, message_id_header: "<reply-target@acme.com>",
      from_email: "support@acme.com", to_email: "sarah@customer.com"
    )

    reply = build_mail(from: "sarah@customer.com", subject: "Re: Cannot access billing portal")
    reply.in_reply_to = "<reply-target@acme.com>"

    assert_no_difference "Conversation.count" do
      assert_difference "ConversationMessage.count", 1 do
        EmailIngestion::Processor.new(@mailbox, reply, provider_uid: "uid_reply").process!
      end
    end

    assert_equal existing_conv.id, ConversationMessage.last.conversation_id
  end

  test "threads reply via ticket number in subject" do
    existing_conv = conversations(:email_ticket)

    reply = build_mail(from: "sarah@customer.com", subject: "Re: [SUP-1001] billing question")

    assert_no_difference "Conversation.count" do
      EmailIngestion::Processor.new(@mailbox, reply, provider_uid: "uid_ticket_ref").process!
    end

    assert_equal existing_conv.id, ConversationMessage.last.conversation_id
  end

  test "skips duplicate emails by provider_uid" do
    mail = build_mail(from: "dup@example.com", subject: "Dup test")

    EmailIngestion::Processor.new(@mailbox, mail, provider_uid: "dup_uid").process!

    assert_no_difference "Conversation.count" do
      EmailIngestion::Processor.new(@mailbox, mail, provider_uid: "dup_uid").process!
    end
  end

  test "skips bounce messages" do
    bounce = build_mail(from: "MAILER-DAEMON@example.com", subject: "Delivery failure")

    assert_no_difference "Conversation.count" do
      EmailIngestion::Processor.new(@mailbox, bounce, provider_uid: "bounce_uid").process!
    end
  end

  test "skips auto-reply messages" do
    auto = build_mail(from: "noreply@example.com", subject: "Out of office")
    auto["Auto-Submitted"] = "auto-replied"

    assert_no_difference "Conversation.count" do
      EmailIngestion::Processor.new(@mailbox, auto, provider_uid: "auto_uid").process!
    end
  end

  test "reopens resolved conversation on new customer reply" do
    conv = conversations(:email_ticket)
    conv.update!(status: :resolved)

    reply = build_mail(from: "sarah@customer.com", subject: "Re: [SUP-1001] still broken")

    EmailIngestion::Processor.new(@mailbox, reply, provider_uid: "reopen_uid").process!

    conv.reload
    assert_equal "open", conv.status
  end

  test "auto-assigns when mailbox has auto_assign enabled" do
    # Keep the operator's heartbeat fresh — the fixture uses a relative time that
    # would otherwise go stale (HEARTBEAT_TTL = 90s) during a long full-suite run.
    operator_profiles(:admin_profile).heartbeat!
    mail = build_mail(from: "unassigned@example.com", subject: "New ticket")

    EmailIngestion::Processor.new(@mailbox, mail, provider_uid: "assign_uid").process!

    conv = Conversation.last
    assert_not_nil conv.assigned_user_id
  end

  test "stores email attachments on the message" do
    mail = build_mail(from: "attach@example.com", subject: "With attachment")
    mail.add_file(filename: "test.txt", content: "file content")

    EmailIngestion::Processor.new(@mailbox, mail, provider_uid: "attach_uid").process!

    msg = ConversationMessage.last
    assert msg.attachments.attached?
    assert_equal "test.txt", msg.attachments.first.filename.to_s
  end

  test "skips attachments over 25MB" do
    mail = build_mail(from: "bigfile@example.com", subject: "Big attachment")
    # Mock a large attachment
    large_body = "x" * (26 * 1024 * 1024)
    mail.add_file(filename: "huge.bin", content: large_body)

    EmailIngestion::Processor.new(@mailbox, mail, provider_uid: "big_uid").process!

    msg = ConversationMessage.last
    assert_not msg.attachments.attached?
  end

  test "updates CC list on thread" do
    existing_conv = conversations(:email_ticket)

    reply = build_mail(from: "sarah@customer.com", subject: "Re: [SUP-1001] update")
    reply.cc = "newcc@example.com"

    EmailIngestion::Processor.new(@mailbox, reply, provider_uid: "cc_uid").process!

    thread = existing_conv.email_thread.reload
    assert_includes thread.cc_list, "newcc@example.com"
  end

  # --- Cross-tenant isolation (security) ---

  # An attacker who knows/forges another account's Message-ID must not be able to
  # graft their email into that account's conversation via In-Reply-To/References.
  def other_account_mailbox
    Mailbox.create!(
      account: accounts(:other_co),
      environment: environments(:other_env),
      name: "Attacker Support",
      email_address: "support@attacker.com",
      provider: :imap,
      ticket_prefix: "ATT",
      next_ticket_number: 5000
    )
  end

  def acme_message_with_header(header)
    conv = conversations(:email_ticket)
    msg = conv.conversation_messages.create!(
      account: @account, sender_type: "User", message_type: :text, content: "internal acme reply"
    )
    EmailMessageDetail.create!(
      conversation_message: msg, message_id_header: header,
      from_email: "support@acme.com", to_email: "sarah@customer.com"
    )
    conv
  end

  test "does NOT thread reply into another account's conversation via forged In-Reply-To" do
    acme_conv = acme_message_with_header("<secret-acme-msg@acme.com>")
    attacker_mailbox = other_account_mailbox

    forged = build_mail(from: "attacker@evil.com", to: "support@attacker.com", subject: "Re: anything")
    forged.in_reply_to = "<secret-acme-msg@acme.com>"

    assert_difference "Conversation.count", 1 do
      EmailIngestion::Processor.new(attacker_mailbox, forged, provider_uid: "forge_irt").process!
    end

    new_conv = Conversation.last
    assert_equal accounts(:other_co).id, new_conv.account_id, "must land in the attacker's own account"
    assert_not_equal acme_conv.id, new_conv.id
    assert_not_equal acme_conv.id, ConversationMessage.last.conversation_id,
      "forged In-Reply-To must not graft into Acme's conversation"
  end

  test "does NOT thread reply into another account's conversation via forged References" do
    # mail.references / mail.message_id are stored bracket-less, so the header is stored bare.
    acme_conv = acme_message_with_header("secret-acme-ref@acme.com")
    attacker_mailbox = other_account_mailbox

    forged = build_mail(from: "attacker@evil.com", to: "support@attacker.com", subject: "Unrelated subject")
    forged.references = "<secret-acme-ref@acme.com>"

    assert_difference "Conversation.count", 1 do
      EmailIngestion::Processor.new(attacker_mailbox, forged, provider_uid: "forge_refs").process!
    end

    new_conv = Conversation.last
    assert_equal accounts(:other_co).id, new_conv.account_id
    assert_not_equal acme_conv.id, ConversationMessage.last.conversation_id,
      "forged References must not graft into Acme's conversation"
  end
end
