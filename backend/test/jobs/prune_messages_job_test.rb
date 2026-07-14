require "test_helper"

class PruneMessagesJobTest < ActiveSupport::TestCase
  setup do
    @account = accounts(:acme)
    @other_account = accounts(:other_co)
    @environment = environments(:production)
    @other_env = environments(:other_env)
    @integration = integrations(:ses)
  end

  # ── Safety: default retention applies ────────────────────────────────────────

  test "prunes messages using default 180-day retention" do
    old_msg = create_message(created_at: 181.days.ago)
    recent_msg = create_message(created_at: 179.days.ago)

    PruneMessagesJob.perform_now

    assert_nil Message.find_by(id: old_msg.id), "Message older than 180 days should be pruned"
    assert Message.find_by(id: recent_msg.id), "Message within 180 days should be kept"
  end

  # ── Respects retention period ───────────────────────────────────────────────

  test "deletes messages older than 30-day retention" do
    @account.update_column(:message_retention_days, 30)

    old_msg = create_message(created_at: 31.days.ago)
    recent_msg = create_message(created_at: 29.days.ago)

    PruneMessagesJob.perform_now

    assert_nil Message.find_by(id: old_msg.id), "Message older than 30 days should be pruned"
    assert Message.find_by(id: recent_msg.id), "Message within 30 days should be kept"
  end

  test "deletes messages older than 60-day retention" do
    @account.update_column(:message_retention_days, 60)

    old_msg = create_message(created_at: 61.days.ago)
    recent_msg = create_message(created_at: 59.days.ago)

    PruneMessagesJob.perform_now

    assert_nil Message.find_by(id: old_msg.id), "Message older than 60 days should be pruned"
    assert Message.find_by(id: recent_msg.id), "Message within 60 days should be kept"
  end

  test "deletes messages older than 90-day retention" do
    @account.update_column(:message_retention_days, 90)

    old_msg = create_message(created_at: 91.days.ago)
    recent_msg = create_message(created_at: 89.days.ago)

    PruneMessagesJob.perform_now

    assert_nil Message.find_by(id: old_msg.id), "Message older than 90 days should be pruned"
    assert Message.find_by(id: recent_msg.id), "Message within 90 days should be kept"
  end

  test "does not delete messages exactly at the cutoff boundary" do
    @account.update_column(:message_retention_days, 30)

    travel_to Time.current do
      # Message created exactly 30 days ago should NOT be pruned (< not <=)
      boundary_msg = create_message(created_at: 30.days.ago)

      PruneMessagesJob.perform_now

      assert Message.find_by(id: boundary_msg.id), "Message exactly at boundary should be kept"
    end
  end

  # ── Multi-tenant isolation ──────────────────────────────────────────────────

  test "does not prune other account's messages when only one has short retention" do
    @account.update_column(:message_retention_days, 30)
    @other_account.update_column(:message_retention_days, 180)

    acme_old = create_message(created_at: 60.days.ago)
    other_old = create_message(account: @other_account, environment: @other_env, created_at: 60.days.ago)

    PruneMessagesJob.perform_now

    assert_nil Message.find_by(id: acme_old.id), "Acme message should be pruned (30-day retention)"
    assert Message.find_by(id: other_old.id), "Other account message should be kept (180-day retention)"
  end

  test "prunes each account according to its own retention period" do
    @account.update_column(:message_retention_days, 90)
    @other_account.update_column(:message_retention_days, 30)

    acme_msg = create_message(created_at: 60.days.ago)
    other_msg = create_message(account: @other_account, environment: @other_env, created_at: 60.days.ago)

    PruneMessagesJob.perform_now

    assert Message.find_by(id: acme_msg.id), "Acme 60-day-old msg should be kept (90-day retention)"
    assert_nil Message.find_by(id: other_msg.id), "Other 60-day-old msg should be pruned (30-day retention)"
  end

  # ── Cascading associated records ────────────────────────────────────────────

  test "deletes associated deliveries when pruning a message" do
    @account.update_column(:message_retention_days, 30)

    old_msg = create_message(created_at: 60.days.ago)
    delivery = Delivery.create!(
      message: old_msg,
      account: @account,
      integration: @integration,
      recipient: "test@example.com",
      status: "accepted"
    )

    PruneMessagesJob.perform_now

    assert_nil Message.find_by(id: old_msg.id)
    assert_nil Delivery.find_by(id: delivery.id), "Delivery should be deleted with its message"
  end

  test "deletes associated opens when pruning a message" do
    @account.update_column(:message_retention_days, 30)

    old_msg = create_message(created_at: 60.days.ago)
    open_record = Open.create!(
      message: old_msg,
      account: @account,
      opened_at: 59.days.ago,
      ip_address: "127.0.0.1"
    )

    PruneMessagesJob.perform_now

    assert_nil Message.find_by(id: old_msg.id)
    assert_nil Open.find_by(id: open_record.id), "Open should be deleted with its message"
  end

  test "purges attachments and blobs when pruning a message" do
    @account.update_column(:message_retention_days, 30)

    old_msg = create_message(created_at: 60.days.ago)
    old_msg.attachments.attach(
      io: StringIO.new("test file content"),
      filename: "test.txt",
      content_type: "text/plain"
    )
    blob_id = old_msg.attachments.first.blob_id

    PruneMessagesJob.perform_now

    assert_nil Message.find_by(id: old_msg.id)
    assert_not ActiveStorage::Attachment.where(record_type: "Message", record_id: old_msg.id).exists?,
      "Attachment record should be purged"
    assert_not ActiveStorage::Blob.exists?(blob_id),
      "Blob should be purged from storage"
  end

  test "does not purge attachments belonging to retained messages" do
    @account.update_column(:message_retention_days, 30)

    recent_msg = create_message(created_at: 10.days.ago)
    recent_msg.attachments.attach(
      io: StringIO.new("keep this"),
      filename: "keep.txt",
      content_type: "text/plain"
    )
    blob_id = recent_msg.attachments.first.blob_id

    PruneMessagesJob.perform_now

    assert Message.find_by(id: recent_msg.id)
    assert ActiveStorage::Blob.exists?(blob_id), "Blob for retained message must not be purged"
  end

  test "does not delete deliveries belonging to retained messages" do
    @account.update_column(:message_retention_days, 30)

    recent_msg = create_message(created_at: 10.days.ago)
    delivery = Delivery.create!(
      message: recent_msg,
      account: @account,
      integration: @integration,
      recipient: "test@example.com",
      status: "accepted"
    )

    PruneMessagesJob.perform_now

    assert Message.find_by(id: recent_msg.id)
    assert Delivery.find_by(id: delivery.id), "Delivery for retained message must not be deleted"
  end

  # ── Child messages ──────────────────────────────────────────────────────────

  test "deletes child messages when parent is pruned" do
    @account.update_column(:message_retention_days, 30)

    parent = create_message(created_at: 60.days.ago)
    child = create_message(created_at: 60.days.ago, parent_message_id: parent.id)

    PruneMessagesJob.perform_now

    assert_nil Message.find_by(id: parent.id), "Parent should be pruned"
    assert_nil Message.find_by(id: child.id), "Child should be pruned with parent"
  end

  test "does not orphan child messages by deleting parent and keeping child" do
    @account.update_column(:message_retention_days, 30)

    parent = create_message(created_at: 60.days.ago)
    child = create_message(created_at: 25.days.ago, parent_message_id: parent.id)

    PruneMessagesJob.perform_now

    # Both should be gone — child follows parent regardless of its own age
    assert_nil Message.find_by(id: parent.id)
    assert_nil Message.find_by(id: child.id), "Child must be deleted with parent even if child is recent"
  end

  test "deletes deliveries on child messages when parent is pruned" do
    @account.update_column(:message_retention_days, 30)

    parent = create_message(created_at: 60.days.ago)
    child = create_message(created_at: 60.days.ago, parent_message_id: parent.id)
    child_delivery = Delivery.create!(
      message: child,
      account: @account,
      integration: @integration,
      recipient: "cc@example.com",
      status: "accepted"
    )

    PruneMessagesJob.perform_now

    assert_nil Delivery.find_by(id: child_delivery.id), "Child delivery should be deleted"
  end

  # ── Preserves recent data ───────────────────────────────────────────────────

  test "preserves all recent messages and their associations" do
    @account.update_column(:message_retention_days, 30)

    recent_msg = create_message(created_at: 5.days.ago)
    delivery = Delivery.create!(
      message: recent_msg,
      account: @account,
      integration: @integration,
      recipient: "test@example.com",
      status: "accepted"
    )
    open_record = Open.create!(
      message: recent_msg,
      account: @account,
      opened_at: 4.days.ago,
      ip_address: "127.0.0.1"
    )

    PruneMessagesJob.perform_now

    assert Message.find_by(id: recent_msg.id)
    assert Delivery.find_by(id: delivery.id)
    assert Open.find_by(id: open_record.id)
  end

  # ── Handles multiple message types (STI) ────────────────────────────────────

  test "prunes all message types equally" do
    @account.update_column(:message_retention_days, 30)

    email = create_message(type: "EmailMessage", created_at: 60.days.ago)
    sms = create_message(type: "SmsMessage", created_at: 60.days.ago, subject: nil)
    whatsapp = create_message(type: "WhatsappMessage", created_at: 60.days.ago, subject: nil)

    PruneMessagesJob.perform_now

    assert_nil Message.find_by(id: email.id)
    assert_nil Message.find_by(id: sms.id)
    assert_nil Message.find_by(id: whatsapp.id)
  end

  # ── Idempotency ─────────────────────────────────────────────────────────────

  test "running the job twice does not cause errors" do
    @account.update_column(:message_retention_days, 30)
    create_message(created_at: 60.days.ago)

    PruneMessagesJob.perform_now

    assert_nothing_raised do
      PruneMessagesJob.perform_now
    end
  end

  test "is a no-op when there are no messages to prune" do
    @account.update_column(:message_retention_days, 30)

    assert_nothing_raised do
      PruneMessagesJob.perform_now
    end
  end

  private

  def create_message(account: @account, environment: @environment, type: "EmailMessage", created_at: Time.current, parent_message_id: nil, subject: "Test")
    msg = Message.new(
      account: account,
      environment: environment,
      type: type,
      to: "test@example.com",
      subject: subject,
      body: "<p>test</p>",
      status: :sent,
      is_deleted: false,
      parent_message_id: parent_message_id
    )
    msg.save!
    msg.update_column(:created_at, created_at)
    msg
  end
end
