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

  private

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
