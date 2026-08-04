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
end
