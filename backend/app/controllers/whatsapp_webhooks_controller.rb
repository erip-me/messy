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

    signature = request.headers["X-Hub-Signature-256"]
    waba_ids = Array(payload["entry"]).filter_map { |e| e["id"].to_s if e.is_a?(Hash) && e["id"].present? }
    integrations = WhatsappIntegration.where(active: true)
      .where("config->>'business_account_id' IN (?)", waba_ids.presence || [""]).to_a
    platform_signed = valid_signature?(body, signature, ENV["META_APP_SECRET"].presence)

    # Each integration is authorized separately: by its own app secret, or by our
    # platform app's secret if Embedded Signup proved its WABA. A tenant's own
    # secret can't vouch for another tenant's WABA in the same payload, and a WABA
    # id copied into config can't claim platform-signed traffic.
    authorized = integrations.select do |i|
      (platform_signed && i.platform_verified?) || valid_signature?(body, signature, i.app_secret.presence)
    end
    if authorized.empty? && !platform_signed
      return head(integrations.empty? && ENV["META_APP_SECRET"].blank? ? :not_found : :forbidden)
    end

    digest = Digest::SHA256.hexdigest(body)
    event = WhatsappWebhookEvent.create_or_find_by!(body_sha256: digest) do |e|
      e.payload = payload
      e.integration = authorized.first
      e.account = authorized.first&.account
      e.authorized_integration_ids = authorized.map(&:id)
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
