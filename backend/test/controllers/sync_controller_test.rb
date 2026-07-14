require "test_helper"

class SyncControllerTest < ActionDispatch::IntegrationTest
  def sync_post(payload, env: environments(:production))
    post "/sync",
         params: payload,
         headers: api_key_headers(env),
         as: :json
  end

  # --- Authentication ---

  test "sync requires authentication" do
    post "/sync",
         params: { layouts: [], templates: [] },
         as: :json

    assert_response :unauthorized
  end

  # --- Layout sync ---

  test "sync creates new layouts" do
    payload = {
      layouts: [{ name: "Sync Layout", body: "<html>{{ content }}</html>" }],
      templates: []
    }

    assert_difference "Layout.count", 1 do
      sync_post(payload)
    end

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal 1, json["layouts"]["created"]
    assert_equal 0, json["layouts"]["updated"]
  end

  test "sync updates existing layouts" do
    layout = layouts(:default_layout)
    new_body = "<div class='wrapper'>{{ content }}</div>"

    payload = {
      layouts: [{ name: layout.name, body: new_body }],
      templates: []
    }

    assert_no_difference "Layout.count" do
      sync_post(payload)
    end

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal 0, json["layouts"]["created"]
    assert_equal 1, json["layouts"]["updated"]
    assert_equal new_body, layout.reload.body
  end

  test "sync upserts layout transformers" do
    transformers = {
      "heading" => '<h1 style="font-size: 24px;">{{text}}</h1>',
      "paragraph" => '<p style="color: #666;">{{text}}</p>'
    }

    payload = {
      layouts: [{ name: "Transformer Layout", body: "<html>{{ content }}</html>", transformers: transformers }],
      templates: []
    }

    sync_post(payload)

    assert_response :success
    created_layout = Layout.find_by(name: "Transformer Layout")
    assert_equal transformers, created_layout.transformers
  end

  # --- Folder sync ---

  test "sync creates folders from template folder paths" do
    payload = {
      layouts: [],
      templates: [{
        folder: "notifications",
        trigger: "notify.test",
        name: "Notify Test",
        channel: "email",
        subject: "Test",
        body: "Hello"
      }]
    }

    assert_difference "Folder.count", 1 do
      sync_post(payload)
    end

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal 1, json["folders"]["created"]

    folder = Folder.find_by(name: "notifications", environment: environments(:production))
    assert_not_nil folder
    assert_nil folder.parent_folder_id
  end

  test "sync creates nested folders" do
    payload = {
      layouts: [],
      templates: [{
        folder: "sellers/onboarding",
        trigger: "seller.onboard",
        name: "Seller Onboarding",
        channel: "email",
        subject: "Welcome",
        body: "Hello seller"
      }]
    }

    assert_difference "Folder.count", 2 do
      sync_post(payload)
    end

    assert_response :success
    parent = Folder.find_by(name: "sellers", environment: environments(:production), parent_folder_id: nil)
    child = Folder.find_by(name: "onboarding", environment: environments(:production), parent_folder_id: parent.id)
    assert_not_nil parent
    assert_not_nil child
  end

  test "sync nests multiple siblings under a shared parent" do
    # Regression: when an ancestor folder was already created by an earlier
    # template in the same sync, later siblings must still nest under it rather
    # than being flattened to the root.
    payload = {
      layouts: [],
      templates: [
        { folder: "drips/firstbid", trigger: "drip.firstbid", name: "Firstbid", channel: "email", subject: "A", body: "a" },
        { folder: "drips/gold",     trigger: "drip.gold",     name: "Gold",     channel: "email", subject: "B", body: "b" },
        { folder: "drips/peter",    trigger: "drip.peter",    name: "Peter",    channel: "email", subject: "C", body: "c" }
      ]
    }

    sync_post(payload)
    assert_response :success

    drips = Folder.find_by(name: "drips", environment: environments(:production), parent_folder_id: nil)
    assert_not_nil drips
    %w[firstbid gold peter].each do |child_name|
      child = Folder.find_by(name: child_name, environment: environments(:production))
      assert_not_nil child, "#{child_name} folder should exist"
      assert_equal drips.id, child.parent_folder_id, "#{child_name} should nest under drips, not flatten to root"
    end
  end

  # --- Template sync ---

  test "sync creates new templates" do
    payload = {
      layouts: [],
      templates: [{
        trigger: "order.placed",
        name: "Order Placed",
        channel: "email",
        subject: "Order Confirmed",
        preview: "Your order has been placed",
        body: "# Order Confirmed\n\nThank you!",
        body_format: "markdown"
      }]
    }

    assert_difference "Template.count", 1 do
      sync_post(payload)
    end

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal 1, json["templates"]["created"]

    template = Template.find_by(trigger: "order.placed", channel: "email")
    assert_equal "Order Placed", template.name
    assert_equal "Order Confirmed", template.subject
    assert_equal "Your order has been placed", template.preview
    assert_equal "markdown", template.body_format
  end

  test "sync updates existing templates" do
    existing = templates(:welcome)

    payload = {
      layouts: [],
      templates: [{
        trigger: existing.trigger,
        channel: existing.channel,
        name: "Updated Welcome",
        subject: "New Subject",
        body: "Updated body"
      }]
    }

    assert_no_difference "Template.count" do
      sync_post(payload)
    end

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal 0, json["templates"]["created"]
    assert_equal 1, json["templates"]["updated"]

    existing.reload
    assert_equal "Updated Welcome", existing.name
    assert_equal "New Subject", existing.subject
  end

  test "sync resolves layout name to id" do
    layout = layouts(:default_layout)

    payload = {
      layouts: [],
      templates: [{
        trigger: "layout.test",
        name: "Layout Test",
        channel: "email",
        subject: "Test",
        body: "Hello",
        layout: layout.name
      }]
    }

    sync_post(payload)

    assert_response :success
    template = Template.find_by(trigger: "layout.test")
    assert_equal layout.id, template.layout_id
  end

  test "sync resolves folder path to id" do
    payload = {
      layouts: [],
      templates: [{
        folder: "accounts",
        trigger: "account.created",
        name: "Account Created",
        channel: "email",
        subject: "Welcome",
        body: "Hello"
      }]
    }

    sync_post(payload)

    assert_response :success
    folder = Folder.find_by(name: "accounts", environment: environments(:production))
    template = Template.find_by(trigger: "account.created")
    assert_equal folder.id, template.folder_id
  end

  test "sync defaults body_format to markdown" do
    payload = {
      layouts: [],
      templates: [{
        trigger: "default.format",
        name: "Default Format",
        channel: "email",
        subject: "Test",
        body: "# Hello"
      }]
    }

    sync_post(payload)

    assert_response :success
    template = Template.find_by(trigger: "default.format")
    assert_equal "markdown", template.body_format
  end

  # --- Idempotency ---

  test "sync is idempotent" do
    payload = {
      layouts: [{ name: "Idempotent Layout", body: "<html>{{ content }}</html>" }],
      templates: [{
        trigger: "idempotent.test",
        name: "Idempotent",
        channel: "email",
        subject: "Test",
        body: "Hello"
      }]
    }

    sync_post(payload)
    assert_response :success
    first_json = JSON.parse(response.body)
    assert_equal 1, first_json["layouts"]["created"]
    assert_equal 1, first_json["templates"]["created"]

    # Run again — should update, not create
    assert_no_difference ["Layout.count", "Template.count"] do
      sync_post(payload)
    end

    assert_response :success
    second_json = JSON.parse(response.body)
    assert_equal 0, second_json["layouts"]["created"]
    assert_equal 1, second_json["layouts"]["updated"]
    assert_equal 0, second_json["templates"]["created"]
    assert_equal 1, second_json["templates"]["updated"]
  end

  # --- Purge ---

  test "sync with purge removes orphaned templates" do
    # Create a template that has no message references
    orphan = Template.create!(
      account: accounts(:acme), environment: environments(:production),
      name: "Orphan", trigger: "orphan.test", channel: "email",
      subject: "Orphan", body: "Will be purged", body_format: "html"
    )
    assert Template.exists?(orphan.id)

    # Sync with a different template and purge=true — include all fixture
    # templates that have message FK references to avoid FK violations
    payload = {
      layouts: [],
      templates: [
        { trigger: "new.template", name: "New Only", channel: "email", subject: "New", body: "Only this one" },
        { trigger: "user.signup", name: "Welcome Email", channel: "email", subject: "Welcome", body: "hi" },
        { trigger: "user.signup", name: "Welcome SMS", channel: "sms", body: "hi" },
        { trigger: "user.password_reset", name: "Password Reset", channel: "email", subject: "Reset", body: "reset" },
        { trigger: "user.markdown_welcome", name: "Markdown", channel: "email", subject: "Welcome", body: "# hi" }
      ],
      purge: true
    }

    sync_post(payload)

    assert_response :success
    json = JSON.parse(response.body)
    assert json["purged"].to_i > 0
    assert_not Template.exists?(orphan.id)
  end

  test "sync without purge keeps orphaned templates" do
    existing = templates(:welcome)

    payload = {
      layouts: [],
      templates: [{
        trigger: "another.new",
        name: "Another New",
        channel: "email",
        subject: "New",
        body: "Body"
      }],
      purge: false
    }

    sync_post(payload)

    assert_response :success
    assert Template.exists?(existing.id)
  end

  # --- Error handling ---

  test "sync rolls back on validation error" do
    original_layout_count = Layout.count
    original_template_count = Template.count

    payload = {
      layouts: [{ name: "Good Layout", body: "<html>{{ content }}</html>" }],
      templates: [{
        trigger: "good.template",
        name: "Good",
        channel: "email",
        subject: "Good",
        body: "Good body"
      }, {
        trigger: "",
        name: "",
        channel: "email",
        body: ""
      }]
    }

    sync_post(payload)

    assert_response :unprocessable_entity
    assert_equal original_layout_count, Layout.count
    assert_equal original_template_count, Template.count
  end

  test "sync returns error for unknown layout reference" do
    payload = {
      layouts: [],
      templates: [{
        trigger: "bad.layout",
        name: "Bad Layout Ref",
        channel: "email",
        subject: "Test",
        body: "Hello",
        layout: "nonexistent_layout"
      }]
    }

    sync_post(payload)

    assert_response :unprocessable_entity
    json = JSON.parse(response.body)
    assert json["errors"].any? { |e| e["errors"].any? { |msg| msg.include?("nonexistent_layout") } }
  end

  test "sync returns detailed error messages" do
    payload = {
      layouts: [],
      templates: [{
        trigger: "err.one",
        name: "Error One",
        channel: "invalid_channel",
        body: "Body"
      }, {
        trigger: "",
        name: "",
        channel: "email",
        body: ""
      }]
    }

    sync_post(payload)

    assert_response :unprocessable_entity
    json = JSON.parse(response.body)
    assert json["errors"].length >= 1
    json["errors"].each do |error|
      assert error.key?("trigger") || error.key?("name")
      assert error.key?("errors")
      assert_kind_of Array, error["errors"]
    end
  end

  # --- Full integration flow ---

  test "full sync flow with layouts folders and templates" do
    payload = {
      layouts: [
        { name: "Email Wrapper", body: "<html><body>{{ content }}</body></html>", transformers: { "heading" => "<h1>{{text}}</h1>" } },
        { name: "SMS Wrapper", body: "{{ content }}" }
      ],
      templates: [
        { folder: "sellers", trigger: "seller.welcome", name: "Seller Welcome", channel: "email", subject: "Welcome Seller", body: "# Hello Seller", layout: "Email Wrapper" },
        { folder: "sellers", trigger: "seller.approved", name: "Seller Approved", channel: "email", subject: "You're Approved", body: "# Approved!", layout: "Email Wrapper" },
        { folder: "buyers", trigger: "buyer.welcome", name: "Buyer Welcome", channel: "sms", body: "Welcome buyer!", layout: "SMS Wrapper" }
      ]
    }

    sync_post(payload)

    assert_response :success
    json = JSON.parse(response.body)

    # Layouts
    assert_equal 2, json["layouts"]["created"]
    email_layout = Layout.find_by(name: "Email Wrapper", environment: environments(:production))
    assert_not_nil email_layout
    assert_equal({ "heading" => "<h1>{{text}}</h1>" }, email_layout.transformers)

    # Folders
    assert_equal 2, json["folders"]["created"]
    sellers_folder = Folder.find_by(name: "sellers", environment: environments(:production))
    buyers_folder = Folder.find_by(name: "buyers", environment: environments(:production))
    assert_not_nil sellers_folder
    assert_not_nil buyers_folder

    # Templates
    assert_equal 3, json["templates"]["created"]

    seller_welcome = Template.find_by(trigger: "seller.welcome")
    assert_equal email_layout.id, seller_welcome.layout_id
    assert_equal sellers_folder.id, seller_welcome.folder_id
    assert_equal "email", seller_welcome.channel
    assert_equal "markdown", seller_welcome.body_format

    buyer_welcome = Template.find_by(trigger: "buyer.welcome")
    assert_equal "sms", buyer_welcome.channel
    assert_equal buyers_folder.id, buyer_welcome.folder_id
  end

  test "sync with empty payload succeeds with zeros" do
    sync_post({ layouts: [], templates: [] })

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal 0, json["layouts"]["created"]
    assert_equal 0, json["templates"]["created"]
  end

  test "sync with empty payload succeeds" do
    payload = { layouts: [], templates: [] }

    sync_post(payload)

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal 0, json["layouts"]["created"]
    assert_equal 0, json["templates"]["created"]
  end

  test "sync creates layout and references it in same payload" do
    payload = {
      layouts: [{ name: "Brand New Layout", body: "<div>{{ content }}</div>" }],
      templates: [{
        trigger: "same.payload",
        name: "Same Payload Test",
        channel: "email",
        subject: "Test",
        body: "Hello",
        layout: "Brand New Layout"
      }]
    }

    sync_post(payload)

    assert_response :success
    template = Template.find_by(trigger: "same.payload")
    layout = Layout.find_by(name: "Brand New Layout")
    assert_equal layout.id, template.layout_id
  end
end
