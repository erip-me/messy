require "test_helper"

class WhatsappControllerTest < ActionDispatch::IntegrationTest
  setup do
    @env = environments(:production)
    @env.update!(allow_whatsapp: true)
    @integration = integrations(:whatsapp)
    @admin = users(:admin)
  end

  # --- POST /whatsapp/messages ---

  test "sends text inside the service window and returns the Meta message id" do
    customer_writes!("31612345678", at: 2.hours.ago)
    MetaGraph.expects(:post).with("1234567890/messages", token: "test_whatsapp_token", body: has_entries(
      "to" => "31612345678", "type" => "text", "text" => { "body" => "Hello" }
    )).returns("messages" => [{ "id" => "wamid.sent1" }])

    post "/whatsapp/messages", params: { to: "+31 6 12345678", type: "text", text: "Hello" }, headers: api_key_headers(@env), as: :json

    assert_response :created
    body = response.parsed_body
    assert_equal "wamid.sent1", body["meta_message_id"]
    assert_equal "accepted", body["status"]
    assert body.dig("window", "free_form_allowed")
    message = ConversationMessage.find(body["id"])
    assert_equal ["User", "api"], [message.sender_type, message.metadata.dig("whatsapp", "source")]
  end

  test "a send whose echo or status webhook was stored first still succeeds and keeps the status" do
    conversation = customer_writes!("31612345678", at: 1.hour.ago)
    conversation.conversation_messages.create!(account: conversation.account, sender_type: "User", content: "Hello",
                                               external_id: "wamid.race", metadata: { "whatsapp" => { "source" => "business_app" } })
    WhatsappMessageStatus.create!(account: conversation.account, wamid: "wamid.race", status: "delivered")
    MetaGraph.expects(:post).returns("messages" => [{ "id" => "wamid.race" }])

    post "/whatsapp/messages", params: { to: "31612345678", text: "Hello" }, headers: api_key_headers(@env), as: :json

    assert_response :created
    message = ConversationMessage.find_by!(external_id: "wamid.race")
    assert_equal ["api", "delivered"], [message.metadata.dig("whatsapp", "source"), message.delivery_status]
  end

  test "refuses free-form text outside the window without calling Meta" do
    customer_writes!("31612345678", at: 25.hours.ago)
    MetaGraph.expects(:post).never

    post "/whatsapp/messages", params: { to: "31612345678", text: "Hello" }, headers: api_key_headers(@env), as: :json

    assert_response :unprocessable_entity
    assert_equal "template_required", response.parsed_body["code"]
    refute response.parsed_body.dig("window", "free_form_allowed")
  end

  test "sends a template to a number that never wrote in" do
    MetaGraph.expects(:post).with("1234567890/messages", token: "test_whatsapp_token", body: has_entries(
      "type" => "template", "template" => { "name" => "order_update", "language" => { "code" => "nl" } }
    )).returns("messages" => [{ "id" => "wamid.tpl" }])

    post "/whatsapp/messages", params: { to: "31612345678", type: "template", template: { name: "order_update", language: "nl" } },
      headers: api_key_headers(@env), as: :json

    assert_response :created
    assert_equal "wamid.tpl", response.parsed_body["meta_message_id"]
  end

  test "validates the request" do
    post "/whatsapp/messages", params: { to: "12", text: "x" }, headers: api_key_headers(@env), as: :json
    assert_response :unprocessable_entity

    post "/whatsapp/messages", params: { to: "31612345678", type: "template", template: { name: "x" } }, headers: api_key_headers(@env), as: :json
    assert_response :unprocessable_entity

    post "/whatsapp/messages", params: { to: "31612345678", type: "sticker" }, headers: api_key_headers(@env), as: :json
    assert_response :unprocessable_entity
  end

  test "requires authentication and an enabled channel" do
    post "/whatsapp/messages", params: { to: "31612345678", text: "x" }, as: :json
    assert_response :unauthorized

    @env.update!(allow_whatsapp: false)
    post "/whatsapp/messages", params: { to: "31612345678", text: "x" }, headers: api_key_headers(@env), as: :json
    assert_response :forbidden
  end

  test "surfaces Meta errors as 502 and records them" do
    customer_writes!("31612345678", at: 1.hour.ago)
    MetaGraph.expects(:post).raises(MetaGraph::Error.new("Graph API 400: Recipient not valid", status: 400, code: 131026))

    post "/whatsapp/messages", params: { to: "31612345678", text: "Hi" }, headers: api_key_headers(@env), as: :json

    assert_response :bad_gateway
    assert_equal 131026, response.parsed_body["meta_error_code"]
    assert_equal 131026, @integration.reload.config.dig("last_error", "code")
  end

  # --- GET /whatsapp/window ---

  test "window reports whether free-form replies are allowed" do
    get "/whatsapp/window", params: { to: "31612345678" }, headers: api_key_headers(@env)
    refute response.parsed_body["free_form_allowed"]

    customer_writes!("31612345678", at: 1.hour.ago)
    get "/whatsapp/window", params: { to: "31612345678" }, headers: api_key_headers(@env)
    assert response.parsed_body["free_form_allowed"]
    assert_in_delta 23.hours.from_now, Time.zone.parse(response.parsed_body["window_expires_at"]), 5
  end

  test "window only considers the environment's own business number" do
    other = WhatsappIntegration.create!(account: accounts(:acme), environment: environments(:staging), vendor: "whatsapp",
      config: { "phone_id" => "5550001", "business_account_id" => "other-waba", "token" => "t2" })
    other_convo = WhatsappInbox.new(other).conversation_for("31612345678")
    other_convo.conversation_messages.create!(account: other_convo.account, sender_type: "Customer", content: "hi", created_at: 1.hour.ago)

    get "/whatsapp/window", params: { to: "31612345678" }, headers: api_key_headers(@env)

    refute response.parsed_body["free_form_allowed"]
    assert_nil response.parsed_body["conversation_id"]
  end

  # --- Inbox reply ---

  test "an operator reply in a whatsapp conversation is sent through the Cloud API" do
    conversation = customer_writes!("31612345678", at: 1.hour.ago)
    MetaGraph.expects(:post).returns("messages" => [{ "id" => "wamid.op" }])

    post "/conversations/#{conversation.id}/create_message", params: { content: "On it!" }, headers: auth_headers(@admin), as: :json

    assert_response :created
    assert_equal "wamid.op", response.parsed_body.dig("message", "external_id")
    assert_equal @admin.id, ConversationMessage.find_by!(external_id: "wamid.op").sender_id
  end

  test "private notes in a whatsapp conversation stay internal" do
    conversation = customer_writes!("31612345678", at: 30.hours.ago)
    MetaGraph.expects(:post).never

    post "/conversations/#{conversation.id}/create_message", params: { content: "call back", private: true }, headers: auth_headers(@admin), as: :json

    assert_response :created
  end

  test "conversation detail exposes the whatsapp window" do
    conversation = customer_writes!("31612345678", at: 30.hours.ago)

    get "/conversations/#{conversation.id}", headers: auth_headers(@admin)

    assert_equal false, response.parsed_body.dig("conversation", "whatsapp", "free_form_allowed")
  end

  test "message pagination follows created_at even when history was inserted later" do
    conversation = customer_writes!("31612345678", at: 1.hour.ago)
    recent = conversation.conversation_messages.create!(account: conversation.account, sender_type: "User", content: "recent", created_at: 30.minutes.ago)
    old = conversation.conversation_messages.create!(account: conversation.account, sender_type: "Customer", content: "old history", created_at: 10.days.ago)

    get "/conversations/#{conversation.id}/messages", params: { before: recent.id }, headers: auth_headers(@admin)

    ids = response.parsed_body["messages"].map { |m| m["id"] }
    assert_includes ids, old.id
    refute_includes ids, recent.id
  end

  # --- Embedded Signup ---

  test "embedded signup exchanges the code, subscribes the app and stores a coexistence number" do
    @integration.update!(environment: environments(:staging))
    MetaGraph.expects(:get).with("oauth/access_token", client_id: "app123", client_secret: "sekret", code: "the-code")
      .returns("access_token" => "business-token")
    MetaGraph.expects(:get).with("waba-1/phone_numbers", token: "business-token", fields: "id,display_phone_number,verified_name")
      .returns("data" => [{ "id" => "phone-1", "display_phone_number" => "+31 6 87026099", "verified_name" => "Husttle" }])
    MetaGraph.expects(:get).with("phone-1", token: "business-token", fields: "is_on_biz_app,platform_type")
      .returns("is_on_biz_app" => true, "platform_type" => "CLOUD_API")
    MetaGraph.expects(:post).with("waba-1/subscribed_apps", token: "business-token").returns("success" => true)
    WhatsappCoexistenceSyncJob.expects(:perform_later).once

    with_env("META_APP_ID" => "app123", "META_APP_SECRET" => "sekret") do
      post "/whatsapp/embedded_signup", params: { code: "the-code", waba_id: "waba-1", business_id: "biz-1" },
        headers: auth_headers(@admin).merge("X-Environment-Id" => @env.id.to_s), as: :json
    end

    assert_response :created
    integration = WhatsappIntegration.for_waba("waba-1")
    assert_equal ["phone-1", "business-token", "biz-1", true],
                 [integration.phone_id, integration.token, integration.config["business_id"], integration.config.dig("onboarding", "coexistence")]
    assert_equal @env, integration.environment
    assert integration.inbox_enabled?
    assert integration.platform_verified?
    refute_includes response.body, "business-token"
  end

  test "an unverified copy of the WABA id in another workspace doesn't block signup" do
    @integration.update!(account: accounts(:other_co), environment: nil)
    MetaGraph.stubs(:get).with("oauth/access_token", anything).returns("access_token" => "tok")
    MetaGraph.stubs(:get).with("9876543210/phone_numbers", anything).returns("data" => [{ "id" => "p1" }])
    MetaGraph.stubs(:get).with("p1", anything).returns({})
    MetaGraph.stubs(:post).returns("success" => true)

    with_env("META_APP_ID" => "app123", "META_APP_SECRET" => "sekret") do
      post "/whatsapp/embedded_signup", params: { code: "c", waba_id: "9876543210" },
        headers: auth_headers(@admin).merge("X-Environment-Id" => @env.id.to_s), as: :json
    end

    assert_response :created
    assert_equal accounts(:acme), WhatsappIntegration.find_by(platform_verified_waba_id: "9876543210").account
  end

  test "a stale verification marker (WABA since changed) doesn't block signup" do
    @integration.update!(account: accounts(:other_co), environment: nil, platform_verified_waba_id: "9876543210",
                         config: @integration.config.merge("business_account_id" => "moved-on"))
    MetaGraph.stubs(:get).with("oauth/access_token", anything).returns("access_token" => "tok")
    MetaGraph.stubs(:get).with("9876543210/phone_numbers", anything).returns("data" => [{ "id" => "p1" }])
    MetaGraph.stubs(:get).with("p1", anything).returns({})
    MetaGraph.stubs(:post).returns("success" => true)

    with_env("META_APP_ID" => "app123", "META_APP_SECRET" => "sekret") do
      post "/whatsapp/embedded_signup", params: { code: "c", waba_id: "9876543210" },
        headers: auth_headers(@admin).merge("X-Environment-Id" => @env.id.to_s), as: :json
    end

    assert_response :created
  end

  test "embedded signup is admin-only and needs server config" do
    post "/whatsapp/embedded_signup", params: { code: "c", waba_id: "w" }, headers: auth_headers(users(:regular)), as: :json
    assert_response :forbidden

    with_env("META_APP_ID" => nil, "META_APP_SECRET" => nil) do
      post "/whatsapp/embedded_signup", params: { code: "c", waba_id: "w" }, headers: auth_headers(@admin), as: :json
    end
    assert_response :service_unavailable
  end

  test "embedded signup refuses a WABA connected to another environment of the workspace" do
    @integration.update!(environment: environments(:staging))

    with_env("META_APP_ID" => "app123", "META_APP_SECRET" => "sekret") do
      post "/whatsapp/embedded_signup", params: { code: "c", waba_id: "9876543210" },
        headers: auth_headers(@admin).merge("X-Environment-Id" => @env.id.to_s), as: :json
    end

    assert_response :conflict
    assert_equal environments(:staging), @integration.reload.environment
  end

  test "embedded signup refuses a WABA owned by another workspace" do
    @integration.update!(account: accounts(:other_co), environment: nil, platform_verified_waba_id: "9876543210")

    with_env("META_APP_ID" => "app123", "META_APP_SECRET" => "sekret") do
      post "/whatsapp/embedded_signup", params: { code: "c", waba_id: "9876543210" }, headers: auth_headers(@admin), as: :json
    end

    assert_response :conflict
  end

  # --- Diagnostics ---

  test "diagnostics report config and activity without leaking secrets" do
    MetaGraph.stubs(:get).with("1234567890", anything).returns("display_phone_number" => "+31 6 87026099", "quality_rating" => "GREEN")
    MetaGraph.stubs(:get).with("9876543210/subscribed_apps", anything).returns("data" => [{ "whatsapp_business_api_data" => { "id" => "1", "name" => "Messy" } }])
    customer_writes!("31612345678", at: 1.hour.ago)
    WhatsappWebhookEvent.create!(body_sha256: "d", payload: {}, integration: @integration, error: "boom")

    get "/whatsapp/diagnostics", headers: auth_headers(@admin)

    assert_response :ok
    row = response.parsed_body["integrations"].first
    assert_equal "9876543210", row["waba_id"]
    assert row.dig("graph", "token_valid")
    assert_equal "Messy", row.dig("graph", "subscribed_apps", 0, "name")
    assert row["last_inbound_at"]
    assert_equal "boom", row.dig("last_webhook_processing_error", "error")
    refute_includes response.body, "test_whatsapp_token"
    refute_includes response.body, "test_app_secret_xyz789"
  end

  test "diagnostics flag an invalid token" do
    MetaGraph.stubs(:get).raises(MetaGraph::Error.new("Graph API 401: Error validating access token", status: 401, code: 190))

    get "/whatsapp/diagnostics", headers: auth_headers(@admin)

    assert_equal false, response.parsed_body.dig("integrations", 0, "graph", "token_valid")
  end

  private

  def customer_writes!(wa_id, at:)
    inbox = WhatsappInbox.new(@integration)
    conversation = inbox.conversation_for(wa_id)
    conversation.conversation_messages.create!(account: conversation.account, sender_type: "Customer", sender_id: conversation.customer_id,
                                               content: "hi", external_id: "wamid.in.#{SecureRandom.hex(4)}", created_at: at,
                                               metadata: { "whatsapp" => { "source" => "customer" } })
    conversation
  end

  def with_env(vars)
    old = vars.keys.to_h { |k| [k, ENV[k]] }
    vars.each { |k, v| ENV[k] = v }
    yield
  ensure
    old.each { |k, v| ENV[k] = v }
  end
end
