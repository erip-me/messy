require "test_helper"

class ProcessSesWebhookJobTest < ActiveJob::TestCase
  setup do
    @delivery = deliveries(:email_delivery)
    @message = messages(:email_one)
    @customer = customers(:recipient)
  end

  # --- Delivery status ---

  test "updates delivery status to delivered" do
    ProcessSesWebhookJob.new.perform(delivery_event)

    @delivery.reload
    assert_equal "delivered", @delivery.status
    assert_not_nil @delivery.completed_at
  end

  test "updates message status from sent to delivered" do
    ProcessSesWebhookJob.new.perform(delivery_event)

    @message.reload
    assert_equal "delivered", @message.status
  end

  # --- Bounce ---

  test "marks delivery as failed on permanent bounce" do
    ProcessSesWebhookJob.new.perform(bounce_event("Permanent", "General"))

    @delivery.reload
    assert_equal "failed", @delivery.status
    assert_equal "Bounce: Permanent / General", @delivery.error
  end

  test "unsubscribes customer on permanent bounce" do
    refute @customer.unsubscribed_from?("email")

    ProcessSesWebhookJob.new.perform(bounce_event("Permanent", "General"))

    @customer.reload
    assert @customer.unsubscribed_from?("email")
  end

  test "stores bounce reason when unsubscribing on permanent bounce" do
    ProcessSesWebhookJob.new.perform(bounce_event("Permanent", "General"))

    @customer.reload
    info = @customer.unsubscribe_info("email")
    assert_equal "bounce", info["reason"]
  end

  test "does not unsubscribe on transient bounce" do
    ProcessSesWebhookJob.new.perform(bounce_event("Transient", "MailboxFull"))

    @customer.reload
    refute @customer.unsubscribed_from?("email")
  end

  test "marks delivery as failed on transient bounce" do
    ProcessSesWebhookJob.new.perform(bounce_event("Transient", "MailboxFull"))

    @delivery.reload
    assert_equal "failed", @delivery.status
    assert_equal "Bounce: Transient / MailboxFull", @delivery.error
  end

  # --- Complaint ---

  test "marks delivery as failed on complaint" do
    ProcessSesWebhookJob.new.perform(complaint_event)

    @delivery.reload
    assert_equal "failed", @delivery.status
    assert_equal "Complaint: abuse", @delivery.error
  end

  test "unsubscribes customer on complaint" do
    refute @customer.unsubscribed_from?("email")

    ProcessSesWebhookJob.new.perform(complaint_event)

    @customer.reload
    assert @customer.unsubscribed_from?("email")
  end

  test "stores complaint reason when unsubscribing on complaint" do
    ProcessSesWebhookJob.new.perform(complaint_event)

    @customer.reload
    info = @customer.unsubscribe_info("email")
    assert_equal "complaint", info["reason"]
  end

  # --- Status regression ---

  test "does not regress status from delivered to accepted" do
    @delivery.update!(status: "delivered")

    ProcessSesWebhookJob.new.perform(delivery_event)

    @delivery.reload
    assert_equal "delivered", @delivery.status
  end

  # --- Edge cases ---

  test "ignores unknown provider_message_id" do
    event = delivery_event(message_id: "unknown-id")

    assert_nothing_raised do
      ProcessSesWebhookJob.new.perform(event)
    end

    @delivery.reload
    assert_equal "accepted", @delivery.status
  end

  test "ignores event without mail data" do
    assert_nothing_raised do
      ProcessSesWebhookJob.new.perform({ "eventType" => "Delivery" })
    end
  end

  test "handles missing customer gracefully on bounce" do
    @customer.destroy!

    assert_nothing_raised do
      ProcessSesWebhookJob.new.perform(bounce_event("Permanent", "General"))
    end

    @delivery.reload
    assert_equal "failed", @delivery.status
  end

  private

  def delivery_event(message_id: nil)
    {
      "eventType" => "Delivery",
      "mail" => { "messageId" => message_id || @delivery.provider_message_id },
      "delivery" => { "recipients" => [@delivery.recipient] }
    }
  end

  def bounce_event(bounce_type, bounce_sub_type, message_id: nil)
    {
      "eventType" => "Bounce",
      "mail" => { "messageId" => message_id || @delivery.provider_message_id },
      "bounce" => {
        "bounceType" => bounce_type,
        "bounceSubType" => bounce_sub_type,
        "bouncedRecipients" => [{ "emailAddress" => @delivery.recipient }]
      }
    }
  end

  def complaint_event(message_id: nil)
    {
      "eventType" => "Complaint",
      "mail" => { "messageId" => message_id || @delivery.provider_message_id },
      "complaint" => {
        "complaintFeedbackType" => "abuse",
        "complainedRecipients" => [{ "emailAddress" => @delivery.recipient }]
      }
    }
  end
end
