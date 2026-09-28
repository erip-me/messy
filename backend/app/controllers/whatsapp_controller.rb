# WhatsApp Cloud API surface beyond the webhook:
#   POST /whatsapp/messages          send text/template (environment API key or JWT)
#   GET  /whatsapp/window?to=...     is a free-form reply allowed right now?
#   GET  /whatsapp/embedded_signup   public Embedded Signup launch config (admin)
#   POST /whatsapp/embedded_signup   finish Embedded Signup / coexistence onboarding (admin)
#   GET  /whatsapp/diagnostics       config + Graph connectivity + last activity (admin)
class WhatsappController < ApplicationController
  include ApiAuthentication

  EMBEDDED_SIGNUP_FEATURE = "whatsapp_business_app_onboarding".freeze

  before_action :require_account_admin!, only: %i[signup_config signup diagnostics]
  before_action :load_integration, only: %i[create_message window]

  def create_message
    return render json: { error: "WhatsApp is disabled for this environment" }, status: :forbidden unless @environment.allow_whatsapp

    to = normalized_to
    return render json: { error: "to must be an international phone number, e.g. 31612345678" }, status: :unprocessable_entity unless to

    conversation = inbox.conversation_for(to)
    message = case params[:type].presence || "text"
              when "text"
                text = params.require(:text).to_s
                return render json: { error: "text is limited to 4096 characters" }, status: :unprocessable_entity if text.length > 4096
                inbox.send_message(conversation, text: text, user: current_user)
              when "template"
                inbox.send_message(conversation, template: WhatsappInbox.template_from(params[:template]), user: current_user)
              else
                return render json: { error: "type must be text or template" }, status: :unprocessable_entity
              end

    render json: {
      id: message.id,
      meta_message_id: message.external_id,
      status: message.delivery_status,
      conversation_id: conversation.id,
      to: to,
      window: window_json(conversation)
    }, status: :created
  rescue WhatsappInbox::WindowClosed
    render json: { error: "The 24h customer service window is closed; send an approved template instead.",
                   code: "template_required", window: window_json(conversation) }, status: :unprocessable_entity
  rescue WhatsappInbox::InvalidParams => e
    render json: { error: e.message }, status: :unprocessable_entity
  rescue MetaGraph::Error => e
    render json: { error: e.message, meta_error_code: e.code }, status: :bad_gateway
  end

  def window
    to = normalized_to
    return render json: { error: "to is required" }, status: :unprocessable_entity unless to

    customer = @account.customers.find_by(whatsapp_id: to)
    conversation = customer && @account.conversations.source_whatsapp.find_by(customer: customer)
    render json: { to: to, conversation_id: conversation&.id }.merge(window_json(conversation))
  end

  def signup_config
    render json: {
      configured: embedded_signup_configured?,
      app_id: ENV["META_APP_ID"],
      config_id: ENV["META_ES_CONFIG_ID"],
      graph_api_version: MetaGraph::VERSION,
      extras: { setup: {}, featureType: EMBEDDED_SIGNUP_FEATURE, sessionInfoVersion: "3" }
    }
  end

  # Called by the dashboard after FB.login (Embedded Signup) returns a code and the
  # WA_EMBEDDED_SIGNUP message event names the WABA. Exchanges the code server-side,
  # subscribes our app to the WABA's webhooks and stores the number on this
  # environment's WhatsApp integration. Coexistence numbers must NOT be registered
  # (/register) — they already are, on the Business App.
  def signup
    return render json: { error: "Embedded Signup is not configured on this server" }, status: :service_unavailable unless embedded_signup_configured?
    return render json: { error: "Select an environment first" }, status: :unprocessable_entity unless @environment

    waba_id = params.require(:waba_id).to_s
    code = params.require(:code).to_s
    existing = WhatsappIntegration.for_waba(waba_id)
    if existing && existing.account_id != @account.id
      return render json: { error: "This WhatsApp Business Account is connected to another workspace" }, status: :conflict
    end

    token = MetaGraph.get("oauth/access_token", client_id: ENV["META_APP_ID"],
                          client_secret: ENV["META_APP_SECRET"], code: code)["access_token"]
    numbers = MetaGraph.get("#{waba_id}/phone_numbers", token: token, fields: "id,display_phone_number,verified_name")["data"] || []
    phone = if params[:phone_number_id].present?
              numbers.find { |n| n["id"] == params[:phone_number_id].to_s }
            elsif numbers.one?
              numbers.first
            end
    unless phone
      return render json: { error: "Pass phone_number_id: one of #{numbers.map { |n| n["id"] }.join(", ")}" }, status: :unprocessable_entity
    end

    details = MetaGraph.get(phone["id"], token: token, fields: "is_on_biz_app,platform_type")
    MetaGraph.post("#{waba_id}/subscribed_apps", token: token)

    integration = existing || @environment.integrations.find_by(type: "WhatsappIntegration") ||
                  WhatsappIntegration.new(account: @account, environment: @environment, vendor: "whatsapp")
    integration.config = (integration.config || {}).merge(
      "phone_id" => phone["id"],
      "business_account_id" => waba_id,
      "business_id" => params[:business_id].presence,
      "token" => token,
      "display_phone_number" => phone["display_phone_number"],
      "verified_name" => phone["verified_name"],
      "inbox_enabled" => true,
      "onboarding" => { "method" => "embedded_signup", "coexistence" => details["is_on_biz_app"] == true,
                        "platform_type" => details["platform_type"], "at" => Time.current.iso8601 }
    ).compact
    integration.active = true
    integration.save!

    WhatsappCoexistenceSyncJob.perform_later(integration.id) if details["is_on_biz_app"]
    render json: { integration: integration.as_json }, status: :created
  rescue MetaGraph::Error => e
    render json: { error: e.message, meta_error_code: e.code }, status: :bad_gateway
  end

  def diagnostics
    render json: {
      backend: "ok",
      time: Time.current,
      graph_api_version: MetaGraph::VERSION,
      webhook_url: "#{request.base_url}/whatsapp/webhook",
      app: {
        meta_app_id: ENV["META_APP_ID"],
        app_secret_configured: ENV["META_APP_SECRET"].present?,
        verify_token_configured: ENV["WHATSAPP_VERIFY_TOKEN"].present?,
        embedded_signup_config_id: ENV["META_ES_CONFIG_ID"]
      },
      integrations: @account.integrations.where(type: "WhatsappIntegration").map { |i| integration_diagnostics(i) }
    }
  end

  private

  def inbox
    @inbox ||= WhatsappInbox.new(@integration)
  end

  def load_integration
    @integration = @environment&.resolve_integration(:whatsapp)
    render json: { error: "No WhatsApp integration configured" }, status: :not_found unless @integration
  end

  def normalized_to
    digits = params[:to].to_s.delete("^0-9")
    digits if digits.length.between?(7, 15)
  end

  def window_json(conversation)
    expires = conversation&.whatsapp_window_expires_at
    { free_form_allowed: expires.present? && expires > Time.current, window_expires_at: expires }
  end

  def embedded_signup_configured?
    ENV["META_APP_ID"].present? && ENV["META_APP_SECRET"].present?
  end

  def integration_diagnostics(integration)
    events = WhatsappWebhookEvent.where(integration_id: integration.id)
    messages = ConversationMessage.joins(:conversation)
      .where(conversations: { account_id: @account.id, source: Conversation.sources[:whatsapp] })
    failed_event = events.failed.order(:id).last
    cfg = integration.config

    {
      id: integration.id,
      environment_id: integration.environment_id,
      active: integration.active,
      inbox_enabled: integration.inbox_enabled?,
      waba_id: integration.business_account_id,
      phone_number_id: integration.phone_id,
      display_phone_number: cfg["display_phone_number"],
      verified_name: cfg["verified_name"],
      onboarding: cfg["onboarding"],
      coexistence_sync: cfg["coexistence_sync"],
      last_account_update: cfg["last_account_update"],
      token_configured: integration.token.present?,
      webhook_secret_configured: integration.webhook_app_secret.present?,
      graph: graph_check(integration),
      last_webhook_at: events.maximum(:created_at),
      last_webhook_processing_error: failed_event && { event_id: failed_event.id, error: failed_event.error, at: failed_event.created_at },
      last_inbound_at: messages.where(sender_type: "Customer").maximum(:created_at),
      last_outbound_at: messages.where(sender_type: "User").maximum(:created_at),
      last_error: cfg["last_error"]
    }
  end

  # Live read-only calls: proves the token works and that our app is subscribed
  # to the WABA's webhooks. Graph error 190 = invalid/expired token.
  def graph_check(integration)
    return { ok: false, error: "no token or phone number id configured" } unless integration.token && integration.phone_id

    phone = MetaGraph.get(integration.phone_id, token: integration.token,
                          fields: "display_phone_number,verified_name,quality_rating,platform_type,is_on_biz_app")
    apps = MetaGraph.get("#{integration.business_account_id}/subscribed_apps", token: integration.token)["data"] || []
    { ok: true, token_valid: true, phone: phone.except("id"),
      subscribed_apps: apps.map { |a| a["whatsapp_business_api_data"]&.slice("id", "name") || a } }
  rescue MetaGraph::Error => e
    { ok: false, token_valid: (e.code == 190 ? false : nil), error: e.message }
  end
end
