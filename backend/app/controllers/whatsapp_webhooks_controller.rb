class WhatsappWebhooksController < ApplicationController
  skip_before_action :authenticate_user!, raise: false

  # GET /whatsapp/webhook — Meta verification handshake
  def verify
    mode = params["hub.mode"]
    token = params["hub.verify_token"]
    challenge = params["hub.challenge"]

    # Query by token in the DB instead of loading every active integration and
    # comparing in Ruby (O(n) scan + non-constant-time ==) on each unauthenticated request.
    integration = token.present? &&
      WhatsappIntegration.where(active: true).where("config->>'webhook_verify_token' = ?", token).exists?

    if mode == "subscribe" && integration
      render plain: challenge, status: :ok
    else
      head :forbidden
    end
  end

  # POST /whatsapp/webhook — Meta status update callbacks
  def callback
    body = request.raw_post
    signature = request.headers["X-Hub-Signature-256"]

    payload = JSON.parse(body)
    business_account_id = payload.dig("entry", 0, "id")

    integration = WhatsappIntegration.find_by("config->>'business_account_id' = ?", business_account_id&.to_s)
    unless integration
      head :not_found
      return
    end

    unless valid_signature?(body, signature, integration.app_secret)
      head :forbidden
      return
    end

    ProcessWhatsappWebhookJob.perform_later(payload)
    head :ok
  end

  private

  def valid_signature?(body, signature, app_secret)
    return false unless signature.present? && app_secret.present?
    expected = "sha256=#{OpenSSL::HMAC.hexdigest("SHA256", app_secret, body)}"
    ActiveSupport::SecurityUtils.secure_compare(expected, signature)
  end
end
