require "test_helper"

class DeliverMessageJobTest < ActiveJob::TestCase
  test "delivers message and creates delivery record" do
    message = EmailMessage.create!(
      account: accounts(:acme),
      environment: environments(:production),
      to: "user@example.com",
      subject: "Test",
      body: "Body",
      status: :pending
    )

    SesIntegration.any_instance.stubs(:deliver!)

    assert_difference -> { Delivery.count }, 1 do
      DeliverMessageJob.new.perform(message)
    end

    message.reload
    assert_equal "sent", message.status

    delivery = Delivery.last
    assert_equal accounts(:acme), delivery.account
    assert_equal "user@example.com", delivery.recipient
    assert_not_nil delivery.completed_at
  end

  test "skips expired messages" do
    message = EmailMessage.create!(
      account: accounts(:acme),
      environment: environments(:production),
      to: "user@example.com",
      subject: "Test",
      body: "Body",
      status: :expired
    )

    assert_no_difference -> { Delivery.count } do
      DeliverMessageJob.new.perform(message)
    end
  end

  test "expires stale pending messages" do
    message = EmailMessage.create!(
      account: accounts(:acme),
      environment: environments(:production),
      to: "user@example.com",
      subject: "Test",
      body: "Body",
      status: :pending,
      created_at: 5.hours.ago
    )

    assert_no_difference -> { Delivery.count } do
      DeliverMessageJob.new.perform(message)
    end

    message.reload
    assert_equal "expired", message.status
  end

  test "records error on delivery failure" do
    message = EmailMessage.create!(
      account: accounts(:acme),
      environment: environments(:production),
      to: "user@example.com",
      subject: "Test",
      body: "Body",
      status: :pending
    )

    SesIntegration.any_instance.stubs(:deliver!).raises(StandardError, "delivery failed")

    assert_raises(StandardError) do
      DeliverMessageJob.new.perform(message)
    end

    delivery = Delivery.last
    assert_equal "delivery failed", delivery.error
    assert_not_nil delivery.completed_at
  end

  test "skips rejected messages" do
    message = EmailMessage.create!(
      account: accounts(:acme),
      environment: environments(:production),
      to: "user@example.com",
      subject: "Test",
      body: "Body",
      status: :rejected
    )

    assert_no_difference -> { Delivery.count } do
      DeliverMessageJob.new.perform(message)
    end
  end

  test "fails immediately with no integration configured" do
    message = EmailMessage.create!(
      account: accounts(:other_co),
      environment: environments(:other_env),
      to: "user@example.com",
      subject: "Test",
      body: "Body",
      status: :pending
    )

    assert_no_difference -> { Delivery.count } do
      DeliverMessageJob.new.perform(message)
    end

    message.reload
    assert_equal "failed", message.status
  end

  test "no integration does not raise or retry" do
    message = SmsMessage.create!(
      account: accounts(:other_co),
      environment: environments(:other_env),
      to: "+15551234567",
      body: "Test SMS",
      status: :pending
    )

    assert_nothing_raised do
      assert_no_difference -> { Delivery.count } do
        DeliverMessageJob.new.perform(message)
      end
    end

    message.reload
    assert_equal "failed", message.status
  end

  test "no integration resolves parent status" do
    parent = EmailMessage.create!(
      account: accounts(:other_co),
      environment: environments(:other_env),
      to: "a@example.com, b@example.com",
      subject: "Test",
      body: "Body",
      status: :pending
    )

    child = EmailMessage.create!(
      account: accounts(:other_co),
      environment: environments(:other_env),
      parent_message_id: parent.id,
      to: "a@example.com",
      subject: "Test",
      body: "Body",
      status: :pending
    )

    DeliverMessageJob.new.perform(child)

    child.reload
    assert_equal "failed", child.status

    parent.reload
    assert_equal "failed", parent.status
  end

  test "force flag bypasses staleness check" do
    message = EmailMessage.create!(
      account: accounts(:acme),
      environment: environments(:production),
      to: "user@example.com",
      subject: "Test",
      body: "Body",
      status: :pending,
      created_at: 5.hours.ago
    )

    SesIntegration.any_instance.stubs(:deliver!)

    DeliverMessageJob.new.perform(message, force: true)

    message.reload
    assert_equal "sent", message.status
  end

  test "environment-specific integration is prioritized over account-level" do
    # Create a generic (account-level) email integration
    generic = SmtpIntegration.create!(
      account: accounts(:acme),
      environment: nil,
      kind: :email,
      vendor: "smtp",
      config: { "host" => "generic.example.com" }
    )

    message = EmailMessage.create!(
      account: accounts(:acme),
      environment: environments(:production),
      to: "user@example.com",
      subject: "Test",
      body: "Body",
      status: :pending
    )

    # The environment-specific SES integration should be used, not the generic SMTP
    job = DeliverMessageJob.new
    integration = job.build_integration(message)
    assert_equal integrations(:ses), integration

    generic.destroy
  end

  test "falls back to account-level integration when no env-specific one" do
    generic = SmtpIntegration.create!(
      account: accounts(:acme),
      environment: nil,
      kind: :email,
      vendor: "smtp",
      config: { "host" => "generic.example.com" }
    )

    message = EmailMessage.create!(
      account: accounts(:acme),
      environment: environments(:staging), # staging has no email integration
      to: "user@example.com",
      subject: "Test",
      body: "Body",
      status: :pending
    )

    job = DeliverMessageJob.new
    integration = job.build_integration(message)
    assert_equal generic, integration

    generic.destroy
  end

  test "falls back to account-level integration when env-specific one is inactive" do
    # Create an account-level (default) SES integration
    default_ses = SesIntegration.create!(
      account: accounts(:acme),
      environment: nil,
      kind: :email,
      vendor: "ses",
      config: { "region" => "us-east-1" },
      active: true
    )

    # Create an environment-specific SMTP integration and deactivate it
    env_smtp = SmtpIntegration.create!(
      account: accounts(:acme),
      environment: environments(:staging),
      kind: :email,
      vendor: "smtp",
      config: { "host" => "staging.example.com" },
      active: false
    )

    message = EmailMessage.create!(
      account: accounts(:acme),
      environment: environments(:staging),
      to: "user@example.com",
      subject: "Test",
      body: "Body",
      status: :pending
    )

    job = DeliverMessageJob.new
    integration = job.build_integration(message)
    assert_equal default_ses, integration

    default_ses.destroy
    env_smtp.destroy
  end

  test "skips inactive integrations entirely" do
    # Deactivate the fixture SES integration
    integrations(:ses).update!(active: false)

    message = EmailMessage.create!(
      account: accounts(:acme),
      environment: environments(:production),
      to: "user@example.com",
      subject: "Test",
      body: "Body",
      status: :pending
    )

    job = DeliverMessageJob.new
    integration = job.build_integration(message)
    assert_nil integration

    # Restore fixture
    integrations(:ses).update!(active: true)
  end

  test "inactive env integration falls back to active account-level default" do
    default_ses = SesIntegration.create!(
      account: accounts(:acme),
      environment: nil,
      kind: :email,
      vendor: "ses",
      config: { "region" => "us-east-1" },
      active: true
    )

    env_smtp = SmtpIntegration.create!(
      account: accounts(:acme),
      environment: environments(:staging),
      kind: :email,
      vendor: "smtp",
      config: { "host" => "staging.example.com" },
      active: false
    )

    message = EmailMessage.create!(
      account: accounts(:acme),
      environment: environments(:staging),
      to: "user@example.com",
      subject: "Test",
      body: "Body",
      status: :pending
    )

    job = DeliverMessageJob.new
    integration = job.build_integration(message)
    assert_equal default_ses, integration

    default_ses.destroy
    env_smtp.destroy
  end

  test "passes message with attachments to integration" do
    message = EmailMessage.create!(
      account: accounts(:acme),
      environment: environments(:production),
      to: "user@example.com",
      subject: "Test",
      body: "Body",
      status: :pending
    )

    message.attachments.attach(
      io: StringIO.new("PDF content"),
      filename: "report.pdf",
      content_type: "application/pdf"
    )

    SesIntegration.any_instance.stubs(:deliver!).with do |msg, _recipient|
      msg.attachments.count == 1 && msg.attachments.first.filename.to_s == "report.pdf"
    end

    DeliverMessageJob.new.perform(message)

    message.reload
    assert_equal "sent", message.status
  end

  test "sets recipient from child message to field" do
    parent = EmailMessage.create!(
      account: accounts(:acme),
      environment: environments(:production),
      to: "a@example.com, b@example.com",
      subject: "Test",
      body: "Body",
      status: :sent
    )

    child = EmailMessage.create!(
      account: accounts(:acme),
      environment: environments(:production),
      parent_message_id: parent.id,
      to: "a@example.com",
      subject: "Test",
      body: "Body",
      status: :pending
    )

    SesIntegration.any_instance.expects(:deliver!).with(child, "a@example.com").once

    DeliverMessageJob.new.perform(child)

    delivery = Delivery.last
    assert_equal "a@example.com", delivery.recipient
  end
end
