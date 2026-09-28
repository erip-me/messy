class WhatsappWebhooksController < ApplicationController
  skip_before_action :authenticate_user!, raise: false

  # GET /whatsapp/webhook — Meta verification handshake. Accepts the app-level
  # WHATSAPP_VERIFY_TOKEN (Embedded Signup app) or any active integration's own token.
  def verify
    token = params["hub.verify_token"].to_s
    known = token.present? && (
      (ENV["WHATSAPP_VERIFY_TOKEN"].present? &&
        ActiveSupport::SecurityUtils.secure_compare(ENV["WHATSAPP_VERIFY_TOKEN"], token)) ||
      WhatsappIntegration.where(active: true).where("config->>'webhook_verify_token' = ?", token).exists?
    )

    if params["hub.mode"] == "subscribe" && known
      render plain: params["hub.challenge"], status: :ok
    else
      head :forbidden
    end
  end

  # POST /whatsapp/webhook — every Cloud API notification (messages, statuses,
  # coexistence echoes/history/contacts, account updates). Verified, stored, and
  # acknowledged; all parsing happens in ProcessWhatsappWebhookJob.
  def callback
    body = request.raw_post
    payload = JSON.parse(body) rescue nil
    return head :bad_request unless payload.is_a?(Hash)

    entry = Array(payload["entry"]).first
    integration = WhatsappIntegration.for_waba(entry["id"]) if entry.is_a?(Hash)
    secrets = [integration&.webhook_app_secret, ENV["META_APP_SECRET"].presence].compact.uniq
    return head :not_found if secrets.empty?
    unless secrets.any? { |s| valid_signature?(body, request.headers["X-Hub-Signature-256"], s) }
      return head :forbidden
    end

    digest = Digest::SHA256.hexdigest(body)
    event = WhatsappWebhookEvent.create_or_find_by!(body_sha256: digest) do |e|
      e.payload = payload
      e.integration = integration
      e.account = integration&.account
    end
    # A retry of a delivery we already finished is acknowledged without new work.
    ProcessWhatsappWebhookJob.perform_later(event.id) unless event.processed_at
    head :ok
  end

  private

  def valid_signature?(body, signature, app_secret)
    return false unless signature.present? && app_secret.present?
    expected = "sha256=#{OpenSSL::HMAC.hexdigest("SHA256", app_secret, body)}"
    ActiveSupport::SecurityUtils.secure_compare(expected, signature)
  end
end
