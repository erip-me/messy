require "test_helper"

class DownloadWhatsappMediaJobTest < ActiveJob::TestCase
  setup do
    @integration = integrations(:whatsapp)
    conversation = WhatsappInbox.new(@integration).conversation_for("31612345678")
    @message = conversation.conversation_messages.create!(
      account: conversation.account, sender_type: "Customer", message_type: :attachment, content: "[image]",
      external_id: "wamid.media", metadata: { "whatsapp" => { "integration_id" => @integration.id,
                                                              "media" => { "id" => "media-1", "mime_type" => "image/jpeg" } } }
    )
  end

  test "downloads the media through the Graph API and attaches it privately" do
    MetaGraph.expects(:get).with("media-1", token: "test_whatsapp_token")
      .returns("url" => "https://lookaside.fbsbx.com/whatsapp/media-1", "mime_type" => "image/jpeg", "file_size" => 3)
    MetaGraph.expects(:download).with("https://lookaside.fbsbx.com/whatsapp/media-1", token: "test_whatsapp_token", max_bytes: 100.megabytes)
      .returns("jpg")

    ActionCable.server.expects(:broadcast).with("operator_inbox_#{@message.account_id}", has_entry(type: "message_updated")).once
    ActionCable.server.stubs(:broadcast).with { |channel, _| channel != "operator_inbox_#{@message.account_id}" }
    DownloadWhatsappMediaJob.perform_now(@message.id)
    DownloadWhatsappMediaJob.perform_now(@message.id)

    @message.reload
    assert_equal 1, @message.attachments.count
    assert_equal "image/jpeg", @message.attachments.first.content_type
    assert @message.metadata.dig("whatsapp", "media", "stored_at")
  end

  test "skips media over the size cap" do
    MetaGraph.expects(:get).returns("url" => "https://x", "file_size" => 200.megabytes)
    MetaGraph.expects(:download).never

    DownloadWhatsappMediaJob.perform_now(@message.id)

    assert @message.reload.metadata.dig("whatsapp", "media", "skipped")
  end
end
