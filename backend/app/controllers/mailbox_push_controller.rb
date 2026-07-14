# Receives cloud push notifications and enqueues a catch-up fetch for the target
# mailbox. Unauthenticated (called by Google Pub/Sub / Microsoft Graph, not our
# users); each provider is guarded by a shared secret. These handlers only
# identify the mailbox and enqueue a job — the actual fetch uses the mailbox's
# stored sync cursor, so a spoofed/duplicate ping is harmless.
class MailboxPushController < ApplicationController
  # POST /mailboxes/gmail/push?token=...
  # Body is a Cloud Pub/Sub push envelope wrapping { emailAddress, historyId }.
  def gmail
    return head :forbidden unless ActiveSupport::SecurityUtils.secure_compare(
      params[:token].to_s, ENV["GMAIL_PUSH_TOKEN"].to_s
    ) && ENV["GMAIL_PUSH_TOKEN"].present?

    envelope = JSON.parse(request.raw_post)
    data = JSON.parse(Base64.decode64(envelope.dig("message", "data").to_s))
    email = data["emailAddress"].to_s.downcase

    mailbox = Mailbox.active_mailboxes.gmail.find_by(email_address: email) ||
              Mailbox.active_mailboxes.gmail.where("lower(config->>'oauth_email') = ?", email).first

    PollMailboxJob.perform_later(mailbox.id) if mailbox
    head :no_content
  rescue JSON::ParserError => e
    Rails.logger.warn "[MailboxPush] gmail: bad payload: #{e.message}"
    head :no_content
  end

  # POST /mailboxes/graph/push
  # Two shapes: a validation handshake on subscribe (echo validationToken as
  # text/plain), or a batch of change notifications.
  def graph
    if params[:validationToken].present?
      return render plain: params[:validationToken], status: :ok, content_type: "text/plain"
    end

    payload = JSON.parse(request.raw_post)
    Array(payload["value"]).each do |note|
      next unless ActiveSupport::SecurityUtils.secure_compare(
        note["clientState"].to_s, EmailIngestion::GraphPush.client_state
      )
      sub_id = note["subscriptionId"]
      next if sub_id.blank?

      mailbox = Mailbox.active_mailboxes.office365
                       .where("sync_state->>'subscription_id' = ?", sub_id).first
      PollMailboxJob.perform_later(mailbox.id) if mailbox
    end

    head :accepted
  rescue JSON::ParserError => e
    Rails.logger.warn "[MailboxPush] graph: bad payload: #{e.message}"
    head :accepted
  end
end
