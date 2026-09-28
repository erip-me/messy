# Copies inbound WhatsApp media into Active Storage. Runs off the webhook path;
# Meta media ids expire after 7 days and their download URLs after 5 minutes, so
# the URL is fetched and used in the same run.
class DownloadWhatsappMediaJob < ApplicationJob
  queue_as :default

  MAX_BYTES = 100.megabytes

  retry_on MetaGraph::Error, wait: :polynomially_longer, attempts: 5

  def perform(conversation_message_id)
    message = ConversationMessage.find_by(id: conversation_message_id)
    wa = message&.metadata&.dig("whatsapp") || {}
    media = wa["media"]
    return if media.blank? || message.attachments.attached?

    integration = WhatsappIntegration.find_by(id: wa["integration_id"])
    return unless integration&.token

    info = MetaGraph.get(media["id"], token: integration.token)
    if info["file_size"].to_i > MAX_BYTES
      return store(message, wa.merge("media" => media.merge("skipped" => "larger than #{MAX_BYTES / 1.megabyte} MB")))
    end

    body = MetaGraph.download(info["url"], token: integration.token, max_bytes: MAX_BYTES)
    mime = info["mime_type"].presence || media["mime_type"] || "application/octet-stream"
    ext = Rack::Mime::MIME_TYPES.invert[mime.split(";").first]
    message.attachments.attach(io: StringIO.new(body), content_type: mime,
                               filename: media["filename"].presence || "whatsapp-#{media["id"]}#{ext}")
    store(message, wa.merge("media" => media.merge("stored_at" => Time.current.iso8601)))
    message.broadcast_update
  end

  private

  def store(message, wa)
    message.update_column(:metadata, message.metadata.merge("whatsapp" => wa))
  end
end
