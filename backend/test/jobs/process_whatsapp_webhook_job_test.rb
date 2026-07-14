require "test_helper"

class ProcessWhatsappWebhookJobTest < ActiveJob::TestCase
  setup do
    @delivery = deliveries(:whatsapp_delivery)
    @message = messages(:whatsapp_sent)
  end

  test "updates delivery status from accepted to delivered" do
    payload = build_payload("delivered")

    ProcessWhatsappWebhookJob.new.perform(payload)

    @delivery.reload
    assert_equal "delivered", @delivery.status
  end

  test "updates message status from sent to delivered" do
    payload = build_payload("delivered")

    ProcessWhatsappWebhookJob.new.perform(payload)

    @message.reload
    assert_equal "delivered", @message.status
  end

  test "updates delivery status to read" do
    @delivery.update!(status: "delivered")
    payload = build_payload("read")

    ProcessWhatsappWebhookJob.new.perform(payload)

    @delivery.reload
    assert_equal "read", @delivery.status
  end

  test "does not regress status from read to delivered" do
    @delivery.update!(status: "read")
    payload = build_payload("delivered")

    ProcessWhatsappWebhookJob.new.perform(payload)

    @delivery.reload
    assert_equal "read", @delivery.status
  end

  test "does not regress status from delivered to sent" do
    @delivery.update!(status: "delivered")
    payload = build_payload("sent")

    ProcessWhatsappWebhookJob.new.perform(payload)

    @delivery.reload
    assert_equal "delivered", @delivery.status
  end

  test "handles failed status with error details" do
    payload = build_payload("failed", errors: [{ "code" => 131047, "title" => "Message failed to send" }])

    ProcessWhatsappWebhookJob.new.perform(payload)

    @delivery.reload
    assert_equal "failed", @delivery.status
    assert_equal "131047: Message failed to send", @delivery.error
  end

  test "updates message status to failed" do
    payload = build_payload("failed", errors: [{ "code" => 131047, "title" => "Re-engagement message" }])

    ProcessWhatsappWebhookJob.new.perform(payload)

    @message.reload
    assert_equal "failed", @message.status
  end

  test "ignores unknown provider_message_id" do
    payload = build_payload("delivered", provider_id: "wamid.unknown_id")

    assert_nothing_raised do
      ProcessWhatsappWebhookJob.new.perform(payload)
    end

    @delivery.reload
    assert_equal "accepted", @delivery.status
  end

  test "ignores payload with wrong object type" do
    payload = { "object" => "instagram", "entry" => [] }

    assert_nothing_raised do
      ProcessWhatsappWebhookJob.new.perform(payload)
    end

    @delivery.reload
    assert_equal "accepted", @delivery.status
  end

  test "processes multiple statuses in one payload" do
    second_delivery = Delivery.create!(
      message: @message,
      integration: integrations(:whatsapp),
      account: accounts(:acme),
      recipient: "+31600000000",
      started_at: 1.hour.ago,
      completed_at: 1.hour.ago + 2.seconds,
      provider_message_id: "wamid.second_message_id",
      status: "accepted"
    )

    payload = {
      "object" => "whatsapp_business_account",
      "entry" => [{
        "id" => "9876543210",
        "changes" => [{
          "value" => {
            "messaging_product" => "whatsapp",
            "metadata" => { "phone_number_id" => "1234567890" },
            "statuses" => [
              { "id" => @delivery.provider_message_id, "status" => "delivered", "timestamp" => Time.now.to_i.to_s, "recipient_id" => "31647508676" },
              { "id" => second_delivery.provider_message_id, "status" => "delivered", "timestamp" => Time.now.to_i.to_s, "recipient_id" => "31600000000" }
            ]
          },
          "field" => "messages"
        }]
      }]
    }

    ProcessWhatsappWebhookJob.new.perform(payload)

    @delivery.reload
    second_delivery.reload
    assert_equal "delivered", @delivery.status
    assert_equal "delivered", second_delivery.status
  end

  private

  def build_payload(status, provider_id: nil, errors: nil)
    status_obj = {
      "id" => provider_id || @delivery.provider_message_id,
      "status" => status,
      "timestamp" => Time.now.to_i.to_s,
      "recipient_id" => "31647508676"
    }
    status_obj["errors"] = errors if errors

    {
      "object" => "whatsapp_business_account",
      "entry" => [{
        "id" => "9876543210",
        "changes" => [{
          "value" => {
            "messaging_product" => "whatsapp",
            "metadata" => { "phone_number_id" => "1234567890" },
            "statuses" => [status_obj]
          },
          "field" => "messages"
        }]
      }]
    }
  end
end
