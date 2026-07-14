require "test_helper"

class IntegrationsControllerTest < ActionDispatch::IntegrationTest
  test "index returns integrations with type" do
    get "/integrations", headers: auth_headers(users(:admin)), as: :json

    assert_response :success
    json = JSON.parse(response.body)
    assert_kind_of Array, json
    types = json.map { |i| i["type"] }
    assert_includes types, "SesIntegration"
    assert_includes types, "TwilioIntegration"
  end

  test "create creates integration" do
    assert_difference "Integration.count", 1 do
      post "/integrations",
           params: { integration: {
             type: "SmtpIntegration",
             kind: "email",
             vendor: "smtp",
             environment_id: environments(:staging).id,
             config: { host: "smtp.example.com", port: "587" }
           } },
           headers: auth_headers(users(:admin)), as: :json
    end

    assert_response :created
    json = JSON.parse(response.body)
    assert_equal "SmtpIntegration", json["type"]
  end

  test "update updates integration" do
    integration = integrations(:ses)

    patch "/integrations/#{integration.id}",
          params: { integration: { active: false } },
          headers: auth_headers(users(:admin)), as: :json

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal false, json["active"]
  end

  test "destroy destroys integration" do
    integration = integrations(:twilio)

    assert_difference "Integration.count", -1 do
      delete "/integrations/#{integration.id}", headers: auth_headers(users(:admin)), as: :json
    end

    assert_response :no_content
  end

  test "test sends directly through integration" do
    integration = integrations(:whatsapp)
    integration.stubs(:deliver!).returns("ok")

    WhatsappIntegration.any_instance.stubs(:deliver!).returns("ok")

    post "/integrations/#{integration.id}/test",
         params: { to: "+31647508676" },
         headers: auth_headers(users(:admin)), as: :json

    assert_response :success
    json = JSON.parse(response.body)
    assert json["success"]
    assert_equal "sent", json["status"]
  end

  test "test requires to param" do
    integration = integrations(:whatsapp)

    post "/integrations/#{integration.id}/test",
         params: {},
         headers: auth_headers(users(:admin)), as: :json

    assert_response :unprocessable_entity
  end

  # --- Secret serialization (security) ---

  test "index does not leak provider secrets" do
    get "/integrations", headers: auth_headers(users(:admin)), as: :json
    body = response.body

    assert_no_match(/wJalrXUtnFEMI/, body, "SES secret_access_key leaked")
    assert_no_match(/test_auth_token_example/, body, "Twilio token leaked")
    assert_no_match(/test_whatsapp_token/, body, "WhatsApp token leaked")
    assert_no_match(/test_app_secret_xyz789/, body, "WhatsApp app_secret leaked")
    assert_no_match(/test_server_key/, body, "FCM server_key leaked")
    assert_no_match(/BEGIN PRIVATE KEY/, body, "APNs private_key leaked")
    assert_no_match(/test_vapid_private/, body, "Web push VAPID private key leaked")
  end

  test "show masks secrets but keeps non-secret config and signals configured" do
    get "/integrations/#{integrations(:ses).id}", headers: auth_headers(users(:admin)), as: :json
    json = JSON.parse(response.body)

    assert_equal "[FILTERED]", json["config"]["secret_access_key"], "secret should be masked, not absent"
    assert_equal "us-east-1", json["config"]["region"], "non-secret config preserved"
  end

  test "update with filtered sentinel preserves the existing secret" do
    ses = integrations(:ses)

    patch "/integrations/#{ses.id}",
          params: { integration: { config: {
            region: "eu-west-1", secret_access_key: "[FILTERED]"
          } } },
          headers: auth_headers(users(:admin)), as: :json

    assert_response :success
    ses.reload
    assert_equal "eu-west-1", ses.config["region"], "non-secret config updated"
    assert_equal "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY", ses.config["secret_access_key"],
      "masked sentinel must not overwrite the real secret"
  end

  test "update can still change a secret to a real new value" do
    ses = integrations(:ses)

    patch "/integrations/#{ses.id}",
          params: { integration: { config: { secret_access_key: "NEWREALSECRET123" } } },
          headers: auth_headers(users(:admin)), as: :json

    assert_response :success
    assert_equal "NEWREALSECRET123", ses.reload.config["secret_access_key"]
  end

  test "create rejects an unsupported STI type instead of 500ing" do
    assert_no_difference "Integration.count" do
      post "/integrations",
           params: { integration: { type: "Account", kind: "email", vendor: "x" } },
           headers: auth_headers(users(:admin)), as: :json
    end
    assert_response :unprocessable_entity
  end

  test "create rejects an environment owned by another account" do
    assert_no_difference "Integration.count" do
      post "/integrations",
           params: { integration: {
             type: "SmtpIntegration", kind: "email", vendor: "smtp",
             environment_id: environments(:other_env).id,
             config: { host: "smtp.example.com" }
           } },
           headers: auth_headers(users(:admin)), as: :json
    end
    assert_response :unprocessable_entity
  end
end
