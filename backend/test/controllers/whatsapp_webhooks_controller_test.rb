require "test_helper"

class WhatsappWebhooksControllerTest < ActionDispatch::IntegrationTest
  setup do
    @integration = integrations(:whatsapp)
    @verify_token = "test_verify_token_abc123"
    @app_secret = "test_app_secret_xyz789"
  end

  # --- Verification (GET) ---

  test "verify returns challenge when token matches" do
    get "/whatsapp/webhook", params: {
      "hub.mode" => "subscribe",
      "hub.verify_token" => @verify_token,
      "hub.challenge" => "challenge_string_123"
    }

    assert_response :ok
    assert_equal "challenge_string_123", response.body
  end

  test "verify returns 403 when token does not match" do
    get "/whatsapp/webhook", params: {
      "hub.mode" => "subscribe",
      "hub.verify_token" => "wrong_token",
      "hub.challenge" => "challenge_string_123"
    }

    assert_response :forbidden
  end

  test "verify returns 403 when mode is not subscribe" do
    get "/whatsapp/webhook", params: {
      "hub.mode" => "unsubscribe",
      "hub.verify_token" => @verify_token,
      "hub.challenge" => "challenge_string_123"
    }

    assert_response :forbidden
  end

  # --- Callback (POST) ---

  test "callback returns 200 with valid signature" do
    payload = webhook_payload("delivered")
    signature = compute_signature(payload, @app_secret)

    post "/whatsapp/webhook",
      params: payload,
      headers: { "X-Hub-Signature-256" => signature, "Content-Type" => "application/json" },
      as: :json

    assert_response :ok
  end

  test "callback returns 403 with invalid signature" do
    payload = webhook_payload("delivered")

    post "/whatsapp/webhook",
      params: payload,
      headers: { "X-Hub-Signature-256" => "sha256=invalid", "Content-Type" => "application/json" },
      as: :json

    assert_response :forbidden
  end

  test "callback returns 403 when signature is missing" do
    payload = webhook_payload("delivered")

    post "/whatsapp/webhook",
      params: payload,
      headers: { "Content-Type" => "application/json" },
      as: :json

    assert_response :forbidden
  end

  test "callback returns 404 when business account not found" do
    payload = webhook_payload("delivered", business_account_id: "unknown_id")
    signature = compute_signature(payload, @app_secret)

    post "/whatsapp/webhook",
      params: payload,
      headers: { "X-Hub-Signature-256" => signature, "Content-Type" => "application/json" },
      as: :json

    assert_response :not_found
  end

  test "callback stores the event and queues processing once per unique delivery" do
    payload = webhook_payload("delivered")
    headers = { "X-Hub-Signature-256" => compute_signature(payload, @app_secret), "Content-Type" => "application/json" }

    ProcessWhatsappWebhookJob.expects(:perform_later).once
    assert_difference -> { WhatsappWebhookEvent.count }, 1 do
      post "/whatsapp/webhook", params: payload, headers: headers, as: :json
    end
    assert_response :ok

    event = WhatsappWebhookEvent.last
    event.update!(processed_at: Time.current)
    assert_no_difference -> { WhatsappWebhookEvent.count } do
      post "/whatsapp/webhook", params: payload, headers: headers, as: :json
    end
    assert_response :ok
    assert_equal @integration, event.integration
    assert_equal payload, event.payload
  end

  test "callback rejects a malformed body" do
    post "/whatsapp/webhook", params: "{not json", headers: { "Content-Type" => "application/json", "X-Hub-Signature-256" => "sha256=x" }

    assert_response :bad_request
    assert_equal 0, WhatsappWebhookEvent.count
  end

  test "callback accepts the Embedded Signup app secret from META_APP_SECRET" do
    @integration.update!(config: @integration.config.except("app_secret"), platform_verified_waba_id: "9876543210")
    payload = webhook_payload("delivered")

    with_env("META_APP_SECRET" => "platform_app_secret") do
      post "/whatsapp/webhook", params: payload, as: :json,
        headers: { "X-Hub-Signature-256" => compute_signature(payload, "platform_app_secret"), "Content-Type" => "application/json" }
    end

    assert_response :ok
  end

  test "callback acknowledges and stores a correctly signed event for an unknown WABA" do
    payload = webhook_payload("delivered", business_account_id: "not_connected_yet")

    with_env("META_APP_SECRET" => "platform_app_secret") do
      post "/whatsapp/webhook", params: payload, as: :json,
        headers: { "X-Hub-Signature-256" => compute_signature(payload, "platform_app_secret"), "Content-Type" => "application/json" }
    end

    assert_response :ok
    assert_nil WhatsappWebhookEvent.last.integration
  end

  test "a tenant's own app secret can't authorize another tenant's WABA in the same payload" do
    victim = WhatsappIntegration.create!(account: accounts(:other_co), environment: environments(:other_env), vendor: "whatsapp",
      config: { "phone_id" => "777", "business_account_id" => "victim-waba", "token" => "vt", "app_secret" => "victim_secret" })
    payload = webhook_payload("delivered")
    payload["entry"] << payload["entry"][0].merge("id" => "victim-waba")

    post "/whatsapp/webhook", params: payload, as: :json,
      headers: { "X-Hub-Signature-256" => compute_signature(payload, @app_secret), "Content-Type" => "application/json" }

    assert_response :ok
    assert_equal [@integration.id], WhatsappWebhookEvent.last.authorized_integration_ids
    refute_includes WhatsappWebhookEvent.last.authorized_integration_ids, victim.id
  end

  test "platform-signed events never reach an integration that merely copied the WABA id" do
    @integration.update!(platform_verified_waba_id: "9876543210")
    squatter = WhatsappIntegration.create!(account: accounts(:other_co), environment: environments(:other_env), vendor: "whatsapp",
      config: { "phone_id" => "1234567890", "business_account_id" => "9876543210", "token" => "x", "inbox_enabled" => true })
    payload = webhook_payload("delivered")

    with_env("META_APP_SECRET" => "platform_app_secret") do
      post "/whatsapp/webhook", params: payload, as: :json,
        headers: { "X-Hub-Signature-256" => compute_signature(payload, "platform_app_secret"), "Content-Type" => "application/json" }
    end

    assert_response :ok
    assert_equal [@integration.id], WhatsappWebhookEvent.last.authorized_integration_ids
    refute_includes WhatsappWebhookEvent.last.authorized_integration_ids, squatter.id
  end

  test "verify accepts the app-level WHATSAPP_VERIFY_TOKEN" do
    with_env("WHATSAPP_VERIFY_TOKEN" => "platform_verify") do
      get "/whatsapp/webhook", params: { "hub.mode" => "subscribe", "hub.verify_token" => "platform_verify", "hub.challenge" => "42" }
    end

    assert_response :ok
    assert_equal "42", response.body
  end

  private

  def with_env(vars)
    old = vars.keys.to_h { |k| [k, ENV[k]] }
    vars.each { |k, v| ENV[k] = v }
    yield
  ensure
    old.each { |k, v| ENV[k] = v }
  end

  def webhook_payload(status, business_account_id: "9876543210")
    {
      "object" => "whatsapp_business_account",
      "entry" => [{
        "id" => business_account_id,
        "changes" => [{
          "value" => {
            "messaging_product" => "whatsapp",
            "metadata" => { "display_phone_number" => "15551234567", "phone_number_id" => "1234567890" },
            "statuses" => [{
              "id" => "wamid.HBgLMzE2NDc1MDg2NzYVAgARGBI",
              "status" => status,
              "timestamp" => Time.now.to_i.to_s,
              "recipient_id" => "31647508676"
            }]
          },
          "field" => "messages"
        }]
      }]
    }
  end

  def compute_signature(payload, secret)
    body = payload.to_json
    "sha256=#{OpenSSL::HMAC.hexdigest("SHA256", secret, body)}"
  end
end
