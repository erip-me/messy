require "test_helper"

class ProcessWhatsappWebhookJobTest < ActiveJob::TestCase
  setup do
    @delivery = deliveries(:whatsapp_delivery)
    @message = messages(:whatsapp_sent)
  end

  test "updates delivery status from accepted to delivered" do
    payload = build_payload("delivered")

    run_webhook(payload)

    @delivery.reload
    assert_equal "delivered", @delivery.status
  end

  test "updates message status from sent to delivered" do
    payload = build_payload("delivered")

    run_webhook(payload)

    @message.reload
    assert_equal "delivered", @message.status
  end

  test "updates delivery status to read" do
    @delivery.update!(status: "delivered")
    payload = build_payload("read")

    run_webhook(payload)

    @delivery.reload
    assert_equal "read", @delivery.status
  end

  test "does not regress status from read to delivered" do
    @delivery.update!(status: "read")
    payload = build_payload("delivered")

    run_webhook(payload)

    @delivery.reload
    assert_equal "read", @delivery.status
  end

  test "does not regress status from delivered to sent" do
    @delivery.update!(status: "delivered")
    payload = build_payload("sent")

    run_webhook(payload)

    @delivery.reload
    assert_equal "delivered", @delivery.status
  end

  test "handles failed status with error details" do
    payload = build_payload("failed", errors: [{ "code" => 131047, "title" => "Message failed to send" }])

    run_webhook(payload)

    @delivery.reload
    assert_equal "failed", @delivery.status
    assert_equal "131047: Message failed to send", @delivery.error
  end

  test "updates message status to failed" do
    payload = build_payload("failed", errors: [{ "code" => 131047, "title" => "Re-engagement message" }])

    run_webhook(payload)

    @message.reload
    assert_equal "failed", @message.status
  end

  test "ignores unknown provider_message_id" do
    payload = build_payload("delivered", provider_id: "wamid.unknown_id")

    assert_nothing_raised do
      run_webhook(payload)
    end

    @delivery.reload
    assert_equal "accepted", @delivery.status
  end

  test "ignores payload with wrong object type" do
    payload = { "object" => "instagram", "entry" => [] }

    assert_nothing_raised do
      run_webhook(payload)
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

    run_webhook(payload)

    @delivery.reload
    second_delivery.reload
    assert_equal "delivered", @delivery.status
    assert_equal "delivered", second_delivery.status
  end

  # --- Inbound messages (messages webhook) ---

  test "stores an inbound text as a customer message in a whatsapp conversation" do
    run_webhook(messages_payload([text_message("wamid.in1", "Hi there")], name: "Sheena Nelson"))

    message = ConversationMessage.find_by!(external_id: "wamid.in1")
    conversation = message.conversation
    assert conversation.source_whatsapp?
    assert_equal "Sheena Nelson", conversation.visitor_name
    assert_equal "Customer", message.sender_type
    assert_equal "Hi there", message.content
    assert_equal "customer", message.metadata.dig("whatsapp", "source")
    assert_equal "Sheena", conversation.customer.first_name
    assert_equal "16505551234", conversation.customer.whatsapp_id
    assert_equal Time.zone.at(1_749_416_383), message.created_at
  end

  test "a replayed webhook creates nothing new and fires the inbound hook once" do
    payload = messages_payload([text_message("wamid.dup", "Hello")])
    fired = 0
    callback = ->(*) { fired += 1 }

    ActiveSupport::Notifications.subscribed(callback, WhatsappInbox::INBOUND_EVENT) do
      run_webhook(payload)
      # Same message in a different delivery (Meta re-batches retries).
      run_webhook(payload.merge("retry" => 1))
    end

    assert_equal 1, ConversationMessage.where(external_id: "wamid.dup").count
    assert_equal 1, Customer.where(whatsapp_id: "16505551234").count
    assert_equal 1, Conversation.source_whatsapp.count
    assert_equal 1, fired
  end

  test "inbound media stores the media id and queues exactly one download" do
    image = { "from" => "16505551234", "id" => "wamid.img", "timestamp" => "1749416383", "type" => "image",
              "image" => { "id" => "media-123", "mime_type" => "image/jpeg", "sha256" => "abc", "caption" => "Front print" } }

    DownloadWhatsappMediaJob.expects(:perform_later).once
    run_webhook(messages_payload([image]))
    run_webhook(messages_payload([image]).merge("retry" => 1))

    message = ConversationMessage.find_by!(external_id: "wamid.img")
    assert message.attachment?
    assert_equal "Front print", message.content
    assert_equal "media-123", message.metadata.dig("whatsapp", "media", "id")
  end

  test "parses interactive, button, document, audio, video, location, contacts and reaction messages" do
    base = { "from" => "16505551234", "timestamp" => "1749416383" }
    msgs = [
      base.merge("id" => "w1", "type" => "interactive", "interactive" => { "type" => "button_reply", "button_reply" => { "id" => "yes", "title" => "Yes please" } }),
      base.merge("id" => "w2", "type" => "interactive", "interactive" => { "type" => "list_reply", "list_reply" => { "id" => "m", "title" => "Size M" } }),
      base.merge("id" => "w3", "type" => "button", "button" => { "payload" => "p", "text" => "Stop promotions" }),
      base.merge("id" => "w4", "type" => "document", "document" => { "id" => "m4", "filename" => "techpack.pdf", "mime_type" => "application/pdf" }),
      base.merge("id" => "w5", "type" => "audio", "audio" => { "id" => "m5", "mime_type" => "audio/ogg", "voice" => true }),
      base.merge("id" => "w6", "type" => "video", "video" => { "id" => "m6", "mime_type" => "video/mp4" }),
      base.merge("id" => "w7", "type" => "location", "location" => { "latitude" => 52.37, "longitude" => 4.89, "name" => "Studio" }),
      base.merge("id" => "w8", "type" => "contacts", "contacts" => [{ "name" => { "formatted_name" => "Jan Jansen" } }]),
      base.merge("id" => "w9", "type" => "reaction", "reaction" => { "message_id" => "w1", "emoji" => "👍" }),
      base.merge("id" => "w10", "type" => "text", "text" => { "body" => "reply" }, "context" => { "from" => "15550783881", "id" => "wamid.orig" }),
      base.merge("id" => "w11", "type" => "unsupported", "errors" => [{ "code" => 131051 }])
    ]

    run_webhook(messages_payload(msgs))

    content = ->(id) { ConversationMessage.find_by!(external_id: id).content }
    assert_equal "Yes please", content.("w1")
    assert_equal "Size M", content.("w2")
    assert_equal "Stop promotions", content.("w3")
    assert_equal "techpack.pdf", content.("w4")
    assert_equal "[audio]", content.("w5")
    assert_equal "[video]", content.("w6")
    assert_equal "Studio · 52.37,4.89", content.("w7")
    assert_equal "Jan Jansen", content.("w8")
    assert_equal "Reacted 👍", content.("w9")
    assert_equal "wamid.orig", ConversationMessage.find_by!(external_id: "w10").metadata.dig("whatsapp", "context_id")
    assert_equal "[unsupported]", content.("w11")
  end

  test "a new inbound message reopens a resolved whatsapp conversation" do
    run_webhook(messages_payload([text_message("wamid.a", "first")]))
    conversation = Conversation.source_whatsapp.last
    conversation.update!(status: :resolved)

    run_webhook(messages_payload([text_message("wamid.b", "again")]))

    assert conversation.reload.open?
  end

  test "integrations without the inbox enabled only track statuses" do
    integrations(:whatsapp).update!(config: integrations(:whatsapp).config.except("inbox_enabled"))

    run_webhook(messages_payload([text_message("wamid.off", "hi")]))
    run_webhook(build_payload("delivered"))

    assert_nil ConversationMessage.find_by(external_id: "wamid.off")
    assert_equal "delivered", @delivery.reload.status
  end

  test "entries for integrations the signature didn't authorize are ignored" do
    event = WhatsappWebhookEvent.create!(body_sha256: "unauth", payload: messages_payload([text_message("wamid.inj", "hi")]),
                                         authorized_integration_ids: [])

    ProcessWhatsappWebhookJob.perform_now(event.id)

    assert_nil ConversationMessage.find_by(external_id: "wamid.inj")
  end

  test "changes for another number in the same WABA go to that number's integration only" do
    other = WhatsappIntegration.create!(account: accounts(:acme), environment: environments(:staging), vendor: "whatsapp",
      config: { "phone_id" => "5550001", "business_account_id" => "9876543210", "token" => "t2", "inbox_enabled" => true })
    payload = messages_payload([text_message("wamid.n2", "to number two")])
    payload["entry"][0]["changes"][0]["value"]["metadata"]["phone_number_id"] = "5550001"
    event = WhatsappWebhookEvent.create!(body_sha256: "multi", payload: payload,
                                         authorized_integration_ids: [integrations(:whatsapp).id, other.id])

    ProcessWhatsappWebhookJob.perform_now(event.id)

    message = ConversationMessage.find_by!(external_id: "wamid.n2")
    assert_equal other.id, message.metadata.dig("whatsapp", "integration_id")
    assert_equal "whatsapp_5550001_16505551234", message.conversation.visitor_token

    payload["entry"][0]["changes"][0]["value"]["metadata"]["phone_number_id"] = "not-ours"
    payload["entry"][0]["changes"][0]["value"]["messages"][0]["id"] = "wamid.n3"
    run_webhook(payload)
    assert_nil ConversationMessage.find_by(external_id: "wamid.n3")
  end

  # --- Statuses on inbox messages ---

  test "status updates move an inbox message forward, keep history, and never regress" do
    run_webhook(messages_payload([text_message("wamid.in", "hi")]))
    conversation = Conversation.source_whatsapp.last
    reply = conversation.conversation_messages.create!(account: conversation.account, sender_type: "User",
                                                       content: "Hello!", external_id: "wamid.out", delivery_status: "accepted")

    run_webhook(build_payload("delivered", provider_id: "wamid.out"))
    run_webhook(build_payload("read", provider_id: "wamid.out"))
    run_webhook(build_payload("sent", provider_id: "wamid.out"))
    run_webhook(build_payload("read", provider_id: "wamid.out").merge("again" => true))

    assert_equal "read", reply.reload.delivery_status
    assert_equal %w[delivered read sent], WhatsappMessageStatus.where(wamid: "wamid.out").order(:id).pluck(:status)
  end

  test "a failed status records the error on the integration" do
    run_webhook(build_payload("failed", provider_id: "wamid.x", errors: [{ "code" => 131047, "title" => "Re-engagement message" }]))

    assert_equal 131047, integrations(:whatsapp).reload.config.dig("last_error", "code")
    assert_equal "wamid.x", integrations(:whatsapp).config.dig("last_error", "wamid")
  end

  # --- Coexistence ---

  test "smb_message_echoes are stored as outbound business_app messages" do
    echo = { "from" => "15550783881", "to" => "16505551234", "id" => "wamid.echo", "timestamp" => "1739321024",
             "type" => "text", "text" => { "body" => "Here's the info you requested!" } }

    run_webhook(change_payload("smb_message_echoes", "message_echoes" => [echo]))
    run_webhook(change_payload("smb_message_echoes", "message_echoes" => [echo]).merge("retry" => 1))

    message = ConversationMessage.find_by!(external_id: "wamid.echo")
    assert_equal "User", message.sender_type
    assert_nil message.sender_id
    assert_equal "business_app", message.metadata.dig("whatsapp", "source")
    assert_equal "16505551234", message.conversation.customer.whatsapp_id
    assert_equal 1, ConversationMessage.where(external_id: "wamid.echo").count
  end

  test "history is imported by direction, deduped, and never opens the service window" do
    history = { "history" => [{ "metadata" => { "phase" => 0, "chunk_order" => 1, "progress" => 100 },
      "threads" => [{ "id" => "16505551234", "messages" => [
        { "from" => "15550783881", "id" => "wamid.h1", "timestamp" => 10.hours.ago.to_i.to_s, "type" => "text",
          "text" => { "body" => "Here you go" }, "history_context" => { "status" => "READ" } },
        { "from" => "16505551234", "id" => "wamid.h2", "timestamp" => 9.hours.ago.to_i.to_s, "type" => "text",
          "text" => { "body" => "Thanks!" }, "history_context" => { "status" => "READ" } },
        { "from" => "15550783881", "id" => "wamid.h3", "timestamp" => 8.hours.ago.to_i.to_s, "type" => "media_placeholder",
          "history_context" => { "status" => "PLAYED" } }
      ] }] }] }

    run_webhook(change_payload("history", history))
    run_webhook(change_payload("history", history).merge("retry" => 1))

    business = ConversationMessage.find_by!(external_id: "wamid.h1")
    customer = ConversationMessage.find_by!(external_id: "wamid.h2")
    assert_equal ["User", "business_app", "read"], [business.sender_type, business.metadata.dig("whatsapp", "source"), business.delivery_status]
    assert_equal ["Customer", "customer"], [customer.sender_type, customer.metadata.dig("whatsapp", "source")]
    assert_equal "[media_placeholder]", ConversationMessage.find_by!(external_id: "wamid.h3").content
    assert_equal 3, ConversationMessage.where(external_id: %w[wamid.h1 wamid.h2 wamid.h3]).count
    refute customer.conversation.whatsapp_free_form_allowed?
  end

  test "history sync refusal is recorded as the integration's last error" do
    run_webhook(change_payload("history", "history" => [{ "errors" => [{ "code" => 2593109, "title" => "History sync is turned off" }] }]))

    assert_equal 2593109, integrations(:whatsapp).reload.config.dig("last_error", "code")
  end

  test "smb_app_state_sync upserts contacts" do
    sync = { "state_sync" => [
      { "type" => "contact", "contact" => { "full_name" => "Pablo Morales", "first_name" => "Pablo", "phone_number" => "16505551234" },
        "action" => "add", "metadata" => { "timestamp" => "1739321024" } },
      { "type" => "contact", "contact" => { "phone_number" => "16505559999" }, "action" => "remove" }
    ] }

    run_webhook(change_payload("smb_app_state_sync", sync))

    customer = accounts(:acme).customers.find_by!(whatsapp_id: "16505551234")
    assert_equal ["Pablo", "Morales", "+16505551234"], [customer.first_name, customer.last_name, customer.phone]
    assert_nil accounts(:acme).customers.find_by(whatsapp_id: "16505559999")
  end

  test "account_update (offboarding) is kept on the integration" do
    run_webhook(change_payload("account_update", "phone_number" => "15550783881", "event" => "PARTNER_REMOVED",
                                                 "disconnection_info" => { "reason" => "PRIMARY_INACTIVITY", "initiated_by" => "SYSTEM" }))

    assert_equal "PARTNER_REMOVED", integrations(:whatsapp).reload.config.dig("last_account_update", "event")
  end

  # --- Robustness ---

  test "malformed entries and values are skipped without raising" do
    payload = { "object" => "whatsapp_business_account",
                "entry" => ["junk", { "id" => "9876543210", "changes" => ["junk", { "field" => "messages", "value" => "junk" },
                                                                          { "field" => "messages", "value" => { "messages" => [{ "type" => "text" }] } }] }] }

    event = run_webhook(payload)

    assert event.reload.processed_at
    assert_equal 0, ConversationMessage.where.not(external_id: nil).count
  end

  test "an event for an unknown WABA is marked processed and ignored" do
    event = run_webhook(messages_payload([text_message("wamid.z", "hi")]).deep_merge("entry" => [{ "id" => "unknown" }]))

    assert event.reload.processed_at
  end

  test "already-processed events are skipped" do
    event = WhatsappWebhookEvent.create!(body_sha256: "x", payload: messages_payload([text_message("wamid.p", "hi")]), processed_at: Time.current)

    ProcessWhatsappWebhookJob.perform_now(event.id)

    assert_nil ConversationMessage.find_by(external_id: "wamid.p")
  end

  private

  def run_webhook(payload)
    event = WhatsappWebhookEvent.create!(body_sha256: SecureRandom.hex(32), payload: payload,
                                         authorized_integration_ids: [integrations(:whatsapp).id])
    ProcessWhatsappWebhookJob.perform_now(event.id)
    event
  end

  def text_message(id, body)
    { "from" => "16505551234", "id" => id, "timestamp" => "1749416383", "type" => "text", "text" => { "body" => body } }
  end

  def messages_payload(messages, name: nil)
    value = { "messaging_product" => "whatsapp", "metadata" => { "display_phone_number" => "15550783881", "phone_number_id" => "1234567890" },
              "messages" => messages }
    value["contacts"] = [{ "profile" => { "name" => name }, "wa_id" => "16505551234" }] if name
    change_payload("messages", value)
  end

  def change_payload(field, value)
    { "object" => "whatsapp_business_account",
      "entry" => [{ "id" => "9876543210", "changes" => [{ "field" => field, "value" => value }] }] }
  end

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
