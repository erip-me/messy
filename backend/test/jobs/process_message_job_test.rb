require "test_helper"

class ProcessMessageJobTest < ActiveJob::TestCase
  test "delivers to all recipients when all pass rules" do
    message = EmailMessage.create!(
      account: accounts(:acme),
      environment: environments(:production),
      to: "a@example.com",
      cc: "",
      bcc: "",
      subject: "Test",
      body: "Body",
      status: :pending
    )

    Environment.any_instance.stubs(:check_rules?).returns(:passed)
    DeliverMessageJob.expects(:perform_later).with(message).once

    ProcessMessageJob.new.perform(message)
  end

  test "creates child messages for partial block" do
    message = EmailMessage.create!(
      account: accounts(:acme),
      environment: environments(:production),
      to: "a@example.com, b@example.com",
      cc: "",
      bcc: "",
      subject: "Test",
      body: "Body",
      status: :pending
    )

    Environment.any_instance.stubs(:check_rules?).with(message, "a@example.com").returns(:passed)
    Environment.any_instance.stubs(:check_rules?).with(message, "b@example.com").returns(:failed)

    # One pending child + one rejected child
    assert_difference -> { EmailMessage.count }, 2 do
      DeliverMessageJob.expects(:perform_later).once
      ProcessMessageJob.new.perform(message)
    end

    children = EmailMessage.where(parent_message_id: message.id).order(:id)
    assert_equal 2, children.count

    passed_child = children.find { |c| c.to.include?("a@example.com") }
    rejected_child = children.find { |c| c.to.include?("b@example.com") }

    assert_equal "pending", passed_child.status
    assert_equal "rejected", rejected_child.status
    assert_not_nil passed_child.parent_message_id
    assert_not_nil rejected_child.parent_message_id
  end

  test "rejects all recipients and marks parent rejected when all fail" do
    message = EmailMessage.create!(
      account: accounts(:acme),
      environment: environments(:production),
      to: "blocked@example.com",
      cc: "",
      bcc: "",
      subject: "Test",
      body: "Body",
      status: :pending
    )

    Environment.any_instance.stubs(:check_rules?).returns(:failed)
    DeliverMessageJob.expects(:perform_later).never

    assert_difference -> { EmailMessage.count }, 1 do
      ProcessMessageJob.new.perform(message)
    end

    message.reload
    assert_equal "rejected", message.status

    child = EmailMessage.where(parent_message_id: message.id).last
    assert_equal "rejected", child.status
    assert_includes child.to, "blocked@example.com"
  end

  test "does not mark parent rejected when some recipients pass" do
    message = EmailMessage.create!(
      account: accounts(:acme),
      environment: environments(:production),
      to: "a@example.com, b@example.com",
      cc: "",
      bcc: "",
      subject: "Test",
      body: "Body",
      status: :pending
    )

    Environment.any_instance.stubs(:check_rules?).with(message, "a@example.com").returns(:passed)
    Environment.any_instance.stubs(:check_rules?).with(message, "b@example.com").returns(:failed)

    DeliverMessageJob.expects(:perform_later).once
    ProcessMessageJob.new.perform(message)

    message.reload
    assert_equal "pending", message.status
  end

  test "copies attachments to child messages" do
    message = EmailMessage.create!(
      account: accounts(:acme),
      environment: environments(:production),
      to: "a@example.com, b@example.com",
      cc: "",
      bcc: "",
      subject: "Test",
      body: "Body",
      status: :pending
    )

    message.attachments.attach(
      io: StringIO.new("hello world"),
      filename: "test.txt",
      content_type: "text/plain"
    )

    Environment.any_instance.stubs(:check_rules?).with(message, "a@example.com").returns(:passed)
    Environment.any_instance.stubs(:check_rules?).with(message, "b@example.com").returns(:failed)

    DeliverMessageJob.expects(:perform_later).once
    ProcessMessageJob.new.perform(message)

    children = EmailMessage.where(parent_message_id: message.id).order(:id)
    children.each do |child|
      assert_equal 1, child.attachments.count, "Child message for #{child.to} should have 1 attachment"
      assert_equal "test.txt", child.attachments.first.filename.to_s
    end
  end

  test "suppresses message when recipient customer is unsubscribed" do
    customer = customers(:john)
    customer.unsubscribe_from!("email", reason: "bounce")

    message = EmailMessage.create!(
      account: accounts(:acme),
      environment: environments(:production),
      to: customer.email,
      cc: "",
      bcc: "",
      subject: "Test",
      body: "Body",
      status: :pending
    )

    Environment.any_instance.stubs(:check_rules?).returns(:passed)
    DeliverMessageJob.expects(:perform_later).never

    ProcessMessageJob.new.perform(message)

    message.reload
    assert_equal "suppressed", message.status

    child = EmailMessage.where(parent_message_id: message.id).last
    assert_equal "suppressed", child.status
  end

  test "suppresses only unsubscribed recipients in mixed list" do
    customer = customers(:john)
    customer.unsubscribe_from!("email", reason: "bounce")

    message = EmailMessage.create!(
      account: accounts(:acme),
      environment: environments(:production),
      to: "#{customer.email}, a@example.com",
      cc: "",
      bcc: "",
      subject: "Test",
      body: "Body",
      status: :pending
    )

    Environment.any_instance.stubs(:check_rules?).returns(:passed)
    DeliverMessageJob.expects(:perform_later).once

    ProcessMessageJob.new.perform(message)

    children = EmailMessage.where(parent_message_id: message.id).order(:id)
    assert_equal 2, children.count

    suppressed_child = children.find { |c| c.to.include?(customer.email) }
    passed_child = children.find { |c| c.to.include?("a@example.com") }

    assert_equal "suppressed", suppressed_child.status
    assert_equal "pending", passed_child.status

    message.reload
    assert_equal "pending", message.status
  end

  test "delivers normally when recipient is not unsubscribed" do
    message = EmailMessage.create!(
      account: accounts(:acme),
      environment: environments(:production),
      to: "a@example.com",
      cc: "",
      bcc: "",
      subject: "Test",
      body: "Body",
      status: :pending
    )

    Environment.any_instance.stubs(:check_rules?).returns(:passed)
    DeliverMessageJob.expects(:perform_later).with(message).once

    ProcessMessageJob.new.perform(message)
  end

  test "creates rejected child messages with correct attributes" do
    message = EmailMessage.create!(
      account: accounts(:acme),
      environment: environments(:production),
      to: "rejected@example.com",
      cc: "",
      bcc: "",
      subject: "Important",
      body: "<p>Hello</p>",
      tags: ["test"],
      scope: :any,
      status: :pending
    )

    Environment.any_instance.stubs(:check_rules?).returns(:failed)
    DeliverMessageJob.expects(:perform_later).never

    ProcessMessageJob.new.perform(message)

    child = EmailMessage.where(parent_message_id: message.id).last
    assert_equal "rejected", child.status
    assert_equal message.account, child.account
    assert_equal message.environment, child.environment
    assert_equal message.subject, child.subject
    assert_equal message.body, child.body
    assert_equal message.type, child.type
  end
end
