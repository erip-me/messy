require "test_helper"

class TemplatesControllerTest < ActionDispatch::IntegrationTest
  test "index with api_key returns templates" do
    get "/templates", headers: api_key_headers(environments(:production)), as: :json

    assert_response :success
    json = JSON.parse(response.body)
    assert_kind_of Array, json
    triggers = json.map { |t| t["trigger"] }
    assert_includes triggers, "user.signup"
  end

  test "index returns channel and body_format fields" do
    get "/templates", headers: api_key_headers(environments(:production)), as: :json

    assert_response :success
    json = JSON.parse(response.body)
    email_template = json.find { |t| t["trigger"] == "user.signup" }
    assert_equal "email", email_template["channel"]
    assert_equal "html", email_template["body_format"]
  end

  test "create creates template" do
    assert_difference "Template.count", 1 do
      post "/templates",
           params: { template: { name: "New Template", trigger: "user.welcome", subject: "Welcome", body: "<p>Hi</p>", channel: "email" } },
           headers: api_key_headers(environments(:production)), as: :json
    end

    assert_response :created
    json = JSON.parse(response.body)
    assert_equal "New Template", json["name"]
    assert_equal "email", json["channel"]
    assert_equal "html", json["body_format"]
  end

  test "create with markdown body_format" do
    assert_difference "Template.count", 1 do
      post "/templates",
           params: { template: {
             name: "MD Template", trigger: "user.md_test", subject: "Hi",
             body: "# Hello", channel: "email", body_format: "markdown"
           } },
           headers: api_key_headers(environments(:production)), as: :json
    end

    assert_response :created
    json = JSON.parse(response.body)
    assert_equal "markdown", json["body_format"]
  end

  test "create sms template without subject" do
    assert_difference "Template.count", 1 do
      post "/templates",
           params: { template: { name: "SMS Alert", trigger: "user.sms_alert", body: "Your code is 1234", channel: "sms" } },
           headers: api_key_headers(environments(:production)), as: :json
    end

    assert_response :created
    json = JSON.parse(response.body)
    assert_equal "sms", json["channel"]
  end

  test "create with missing fields returns 422" do
    assert_no_difference "Template.count" do
      post "/templates",
           params: { template: { name: "" } },
           headers: api_key_headers(environments(:production)), as: :json
    end

    assert_response :unprocessable_entity
  end

  test "create with invalid channel returns 422" do
    assert_no_difference "Template.count" do
      post "/templates",
           params: { template: { name: "Bad", trigger: "bad.channel", body: "hi", channel: "fax" } },
           headers: api_key_headers(environments(:production)), as: :json
    end

    assert_response :unprocessable_entity
  end

  test "create with invalid body_format returns 422" do
    assert_no_difference "Template.count" do
      post "/templates",
           params: { template: { name: "Bad", trigger: "bad.format", body: "hi", channel: "email", body_format: "rtf" } },
           headers: api_key_headers(environments(:production)), as: :json
    end

    assert_response :unprocessable_entity
  end

  test "update updates template" do
    template = templates(:welcome)

    patch "/templates/#{template.id}",
          params: { template: { name: "Updated Welcome" } },
          headers: api_key_headers(environments(:production)), as: :json

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal "Updated Welcome", json["name"]
  end

  test "update body_format to markdown" do
    template = templates(:welcome)

    patch "/templates/#{template.id}",
          params: { template: { body_format: "markdown", body: "# Hello" } },
          headers: api_key_headers(environments(:production)), as: :json

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal "markdown", json["body_format"]
  end

  test "destroy destroys template" do
    template = templates(:password_reset)

    assert_difference "Template.count", -1 do
      delete "/templates/#{template.id}",
             headers: api_key_headers(environments(:production)), as: :json
    end

    assert_response :no_content
  end

  # --- Trigger tests ---

  test "trigger creates message from template" do
    ProcessMessageJob.stubs(:perform_now)

    assert_difference "Message.count", 1 do
      post "/messages/trigger",
           params: { trigger: "user.signup", message: { to: "new@example.com" }, data: {} },
           headers: api_key_headers(environments(:production)), as: :json
    end

    assert_response :created
  end

  test "trigger defaults to email when no channel provided" do
    ProcessMessageJob.stubs(:perform_now)

    post "/messages/trigger",
         params: { trigger: "user.signup", message: { to: "new@example.com" }, data: {} },
         headers: api_key_headers(environments(:production)), as: :json

    assert_response :created
    created_message = Message.order(created_at: :desc).first
    assert_equal "EmailMessage", created_message.type
  end

  test "trigger with channel param selects correct template" do
    ProcessMessageJob.stubs(:perform_now)

    post "/messages/trigger",
         params: { trigger: "user.signup", channel: "sms", message: { to: "+1234567890" }, data: {} },
         headers: api_key_headers(environments(:production)), as: :json

    assert_response :created
    created_message = Message.order(created_at: :desc).first
    assert_equal "SmsMessage", created_message.type
  end

  test "trigger with channel builds correct message type" do
    ProcessMessageJob.stubs(:perform_now)

    post "/messages/trigger",
         params: { trigger: "user.signup", channel: "sms", message: { to: "+1234567890" }, data: {} },
         headers: api_key_headers(environments(:production)), as: :json

    assert_response :created
    created_message = Message.order(created_at: :desc).first
    assert_equal "SmsMessage", created_message.type
    assert_equal "Welcome to Acme!", created_message.body
  end

  test "trigger with nonexistent channel returns 422" do
    post "/messages/trigger",
         params: { trigger: "user.signup", channel: "fax", message: { to: "a@b.com" }, data: {} },
         headers: api_key_headers(environments(:production)), as: :json

    assert_response :unprocessable_entity
    json = JSON.parse(response.body)
    assert_equal "Template not found", json["error"]
  end

  test "trigger with nonexistent trigger returns 422" do
    post "/messages/trigger",
         params: { trigger: "nonexistent.trigger", message: { to: "a@b.com" }, data: {} },
         headers: api_key_headers(environments(:production)), as: :json

    assert_response :unprocessable_entity
    json = JSON.parse(response.body)
    assert_equal "Template not found", json["error"]
  end

  test "trigger renders template with layout" do
    ProcessMessageJob.stubs(:perform_now)

    post "/messages/trigger",
         params: { trigger: "user.markdown_welcome", message: { to: "user@example.com" }, data: {} },
         headers: api_key_headers(environments(:production)), as: :json

    assert_response :created
    json = JSON.parse(response.body)
    # The body should be wrapped in the layout
    assert_includes json["body"], "<html>"
    assert_includes json["body"], "</html>"
  end
end
