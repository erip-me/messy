require "test_helper"

class MessagesControllerTest < ActionDispatch::IntegrationTest
  test "index with api_key returns messages" do
    get "/messages", headers: api_key_headers(environments(:production)), as: :json

    assert_response :success
    json = JSON.parse(response.body)
    assert json.key?("data")
    assert json.key?("meta")
    assert_kind_of Array, json["data"]
  end

  test "show returns message with channel and environment" do
    message = messages(:email_one)

    get "/messages/#{message.id}", headers: api_key_headers(environments(:production)), as: :json

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal "email", json["channel"]
    assert_equal "Production", json["environment"]
  end

  test "create creates email message" do
    ProcessMessageJob.stubs(:perform_now)

    assert_difference "Message.count", 1 do
      post "/messages",
           params: { type: "email", message: { to: "user@example.com", subject: "Hi", body: "Hello" } },
           headers: api_key_headers(environments(:production)), as: :json
    end

    assert_response :created
  end

  test "create assigns the chosen sending identity" do
    ProcessMessageJob.stubs(:perform_now)
    identity = accounts(:acme).sending_identities.create!(from_name: "Peter", from_email: "peter@acme.com")

    post "/messages",
         params: { type: "email", message: { to: "user@example.com", subject: "Hi", body: "Hello", sending_identity_id: identity.id } },
         headers: api_key_headers(environments(:production)), as: :json

    assert_response :created
    assert_equal identity.id, Message.order(:id).last.sending_identity_id
  end

  test "create is blocked with 402 once the cloud trial has expired" do
    Stripe.api_key = "sk_test_stub"
    accounts(:acme).update!(plan: "trial", trial_ends_at: 1.day.ago)

    post "/messages",
         params: { type: "email", message: { to: "user@example.com", subject: "Hi", body: "Hello" } },
         headers: api_key_headers(environments(:production)), as: :json

    assert_response :payment_required
  ensure
    Stripe.api_key = nil
  end

  test "create with invalid type returns 422" do
    post "/messages",
         params: { type: "invalid", message: { to: "user@example.com", body: "Hello" } },
         headers: api_key_headers(environments(:production)), as: :json

    assert_response :unprocessable_entity
  end

  test "trigger auto-fills unsubscribe_url without the caller supplying it" do
    ProcessMessageJob.stubs(:perform_now)
    template = accounts(:acme).templates.create!(
      environment: environments(:production), name: "Outreach", trigger: "user.outreach",
      channel: "email", subject: "Hi {{first_name}}",
      body: 'Hi {{first_name}} <a href="{{unsubscribe_url}}">unsubscribe</a>', body_format: "html"
    )

    post "/messages/trigger",
         params: { trigger: "user.outreach", channel: "email", to: "user@example.com", data: { first_name: "Ann" } },
         headers: api_key_headers(environments(:production)), as: :json

    assert_response :created
    message = Message.order(:id).last
    assert_match %r{/track/[a-f0-9]+/unsubscribe}, message.body
    assert_not_includes message.body, "{{unsubscribe_url}}"
    assert_includes message.body, "Hi Ann"
  end

  test "trigger creates message from template" do
    ProcessMessageJob.stubs(:perform_now)

    assert_difference "Message.count", 1 do
      post "/messages/trigger",
           params: { trigger: "user.signup", message: { to: "new@example.com" }, data: {} },
           headers: api_key_headers(environments(:production)), as: :json
    end

    assert_response :created
  end

  test "update updates message" do
    message = messages(:pending_email)
    ActionCable.server.stubs(:broadcast)

    patch "/messages/#{message.id}",
          params: { message: { subject: "Updated Subject" } },
          headers: api_key_headers(environments(:production)), as: :json

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal "Updated Subject", json["subject"]
  end

  # Attachment links are plain browser navigations with no X-Environment-Id, so the
  # request must not be scoped to whichever environment happens to come back first.
  test "attachment downloads for a signed-in user regardless of environment" do
    message = accounts(:acme).messages.create!(
      environment: environments(:staging), type: "EmailMessage",
      to: "user@example.com", subject: "Contract", body: "<p>See attached.</p>"
    )
    message.attachments.attach(io: StringIO.new("%PDF-1.4 fake"), filename: "lease.pdf", content_type: "application/pdf")

    get "/messages/#{message.id}/attachments/#{message.attachments.first.id}?download=1",
        headers: auth_headers(users(:admin))

    assert_response :success
    assert_equal "%PDF-1.4 fake", response.body
  end

  test "attachment is not readable across workspaces" do
    message = messages(:email_one)
    message.attachments.attach(io: StringIO.new("secret"), filename: "s.txt", content_type: "text/plain")

    get "/messages/#{message.id}/attachments/#{message.attachments.first.id}",
        headers: auth_headers(users(:other_user))

    assert_response :not_found
  end

  test "update rejects editing an already-sent message" do
    message = messages(:email_one) # status: sent
    patch "/messages/#{message.id}",
          params: { message: { subject: "Tampered" } },
          headers: api_key_headers(environments(:production)), as: :json

    assert_response :unprocessable_entity
    assert_equal "Welcome to Acme", message.reload.subject
  end

  # --- composer support ---

  def outreach_template(attrs = {})
    accounts(:acme).templates.create!({
      environment: environments(:production), name: "Outreach", trigger: "sales.outreach",
      channel: "email", subject: "Hi {{first_name}}", body: "Hello {{first_name}}", body_format: "html"
    }.merge(attrs))
  end

  def b64(str) = Base64.strict_encode64(str)

  test "trigger defaults the identity to the template's and adds template attachments" do
    ProcessMessageJob.stubs(:perform_now)
    identity = accounts(:acme).sending_identities.create!(from_email: "peter@acme.com")
    t = outreach_template(sending_identity: identity)
    t.attachments.attach(io: StringIO.new("%PDF"), filename: "deck.pdf", content_type: "application/pdf")

    post "/messages/trigger",
         params: { trigger: "sales.outreach", data: { first_name: "Ann" },
                   message: { to: "user@example.com",
                              inline_attachments: [{ filename: "quote.txt", content_type: "text/plain", data: b64("quote") }] } },
         headers: api_key_headers(environments(:production)), as: :json

    assert_response :created
    message = Message.order(:id).last
    assert_equal identity.id, message.sending_identity_id
    assert_equal "sales.outreach", message.trigger
    assert_equal %w[deck.pdf quote.txt], message.attachments.map { |a| a.filename.to_s }.sort
    assert_equal "quote", message.attachments.find { |a| a.filename.to_s == "quote.txt" }.download
  end

  test "trigger keeps an explicit identity over the template's" do
    ProcessMessageJob.stubs(:perform_now)
    outreach_template(sending_identity: accounts(:acme).sending_identities.create!(from_email: "peter@acme.com"))
    explicit = accounts(:acme).sending_identities.create!(from_email: "sara@acme.com")

    post "/messages/trigger",
         params: { trigger: "sales.outreach", data: { first_name: "Ann" }, message: { to: "user@example.com", sending_identity_id: explicit.id } },
         headers: api_key_headers(environments(:production)), as: :json

    assert_equal explicit.id, Message.order(:id).last.sending_identity_id
  end

  test "trigger stores metadata alongside trigger_data tags" do
    ProcessMessageJob.stubs(:perform_now)
    outreach_template

    post "/messages/trigger",
         params: { trigger: "sales.outreach", data: { first_name: "Ann" },
                   message: { to: "user@example.com", metadata: { source: "lalaaji", sent_by_role: "ae", seller_key: "abc12345" } } },
         headers: api_key_headers(environments(:production)), as: :json

    assert_response :created
    message = Message.order(:id).last
    assert_equal({ "source" => "lalaaji", "sent_by_role" => "ae", "seller_key" => "abc12345" }, message.metadata)
    assert_equal [{ "trigger_data" => { "first_name" => "Ann" } }], message.tags
    assert_equal "lalaaji", JSON.parse(response.body)["metadata"]["source"]
  end

  test "trigger rejects invalid base64 inline attachments with 422" do
    outreach_template

    assert_no_difference "Message.count" do
      post "/messages/trigger",
           params: { trigger: "sales.outreach", data: { first_name: "Ann" },
                     message: { to: "user@example.com", inline_attachments: [{ filename: "x.pdf", data: "not base64!!" }] } },
           headers: api_key_headers(environments(:production)), as: :json
    end
    assert_response :unprocessable_entity
  end

  test "create stores flat metadata and returns it" do
    ProcessMessageJob.stubs(:perform_now)

    post "/messages",
         params: { type: "email", message: { to: "user@example.com", subject: "Hi", body: "Hello", metadata: { composer: "custom", count: 2, ok: true } } },
         headers: api_key_headers(environments(:production)), as: :json

    assert_response :created
    assert_equal({ "composer" => "custom", "count" => 2, "ok" => true }, Message.order(:id).last.metadata)

    get "/messages/#{Message.order(:id).last.id}", headers: api_key_headers(environments(:production))
    assert_equal "custom", JSON.parse(response.body)["metadata"]["composer"]
  end

  test "create rejects nested metadata" do
    post "/messages",
         params: { type: "email", message: { to: "user@example.com", subject: "Hi", body: "Hello", metadata: { deep: { x: 1 } } } },
         headers: api_key_headers(environments(:production)), as: :json

    assert_response :unprocessable_entity
  end

  test "create with template_id wraps the body in the template's layout with a real unsubscribe link" do
    ProcessMessageJob.stubs(:perform_now)
    identity = accounts(:acme).sending_identities.create!(from_email: "peter@acme.com")
    layout = environments(:production).layouts.create!(account: accounts(:acme), name: "Composer",
                                             body: "<html>{{ preview }}|{{ content }}|<a href=\"{{ unsubscribe_url }}\">u</a></html>")
    t = outreach_template(layout: layout, sending_identity: identity)
    t.attachments.attach(io: StringIO.new("%PDF"), filename: "deck.pdf", content_type: "application/pdf")

    post "/messages",
         params: { type: "email", message: { to: "user@example.com", subject: "Custom", body: "<p>Edited</p>",
                                             template_id: t.id, preview: "Peek",
                                             inline_attachments: [{ filename: "extra.txt", content_type: "text/plain", data: b64("x") }] } },
         headers: api_key_headers(environments(:production)), as: :json

    assert_response :created
    message = Message.order(:id).last
    assert_equal t.id, message.template_id
    assert_equal identity.id, message.sending_identity_id
    assert_equal "<html>Peek|<p>Edited</p>|<a href=\"#{accounts(:acme).tracking_base_url}/track/#{message.tracking_token}/unsubscribe\">u</a></html>", message.body
    assert_equal %w[deck.pdf extra.txt], message.attachments.map { |a| a.filename.to_s }.sort
  end

  test "create with template_id swaps the preview's unsubscribe placeholder in the body for the real link" do
    ProcessMessageJob.stubs(:perform_now)
    t = outreach_template(layout: nil)

    post "/messages",
         params: { type: "email", message: { to: "user@example.com", subject: "Custom", template_id: t.id,
                                             body: "<p>Edited <a href=\"#{TemplateRenderer::PREVIEW_UNSUBSCRIBE_URL}\">stop</a></p>" } },
         headers: api_key_headers(environments(:production)), as: :json

    assert_response :created
    message = Message.order(:id).last
    assert_equal "<p>Edited <a href=\"#{accounts(:acme).tracking_base_url}/track/#{message.tracking_token}/unsubscribe\">stop</a></p>", message.body
  end

  test "trigger does not ask the caller for variables the template assigns itself" do
    ProcessMessageJob.stubs(:perform_now)
    t = outreach_template(trigger: "sales.assigning", body: "{% assign greeting = 'Hello' %}{{ greeting }} {{ first_name }}")

    post "/messages/trigger",
         params: { trigger: t.trigger, message: { to: "user@example.com" }, data: { first_name: "Ann" } },
         headers: api_key_headers(environments(:production)), as: :json

    assert_response :created
    assert_equal "Hello Ann", Message.order(:id).last.body
  end

  test "create with layout_id alone wraps the body in that layout" do
    ProcessMessageJob.stubs(:perform_now)

    post "/messages",
         params: { type: "email", message: { to: "user@example.com", subject: "Hi", body: "<p>Hi</p>", layout_id: layouts(:default_layout).id } },
         headers: api_key_headers(environments(:production)), as: :json

    assert_response :created
    message = Message.order(:id).last
    assert_equal "<html><body><p>Hi</p></body></html>", message.body
    assert_nil message.template_id
  end

  test "create refuses a template or layout from another environment" do
    other_template = accounts(:acme).templates.create!(environment: environments(:staging), name: "S", trigger: "s", channel: "email", body: "b", body_format: "html")

    post "/messages",
         params: { type: "email", message: { to: "user@example.com", subject: "Hi", body: "Hi", template_id: other_template.id } },
         headers: api_key_headers(environments(:production)), as: :json
    assert_response :unprocessable_entity

    post "/messages",
         params: { type: "email", message: { to: "user@example.com", subject: "Hi", body: "Hi", layout_id: layouts(:other_layout).id } },
         headers: api_key_headers(environments(:production)), as: :json
    assert_response :unprocessable_entity
  end
end
