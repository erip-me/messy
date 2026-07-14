require "test_helper"

class Widget::ConversationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @account = accounts(:acme)
    @visitor_token = "test_visitor_#{SecureRandom.hex(8)}"
    @headers = { "X-Widget-Key" => chat_widget_settings(:acme_settings).widget_key, "X-Visitor-Token" => @visitor_token }
  end

  test "create starts a new conversation" do
    assert_difference "Conversation.count", 1 do
      post "/widget/v1/conversations",
           params: { initial_message: "Hello!", page_url: "https://example.com/pricing" },
           headers: @headers,
           as: :json
    end

    assert_response :created
    json = JSON.parse(response.body)
    assert json["conversation"]["id"].present?
    assert_equal "open", json["conversation"]["status"]
  end

  test "create with tag sets subject" do
    tag = conversation_tags(:pricing_tag)

    post "/widget/v1/conversations",
         params: { initial_message: "About pricing", tag_id: tag.id },
         headers: @headers,
         as: :json

    assert_response :created
    json = JSON.parse(response.body)
    assert_equal "Pricing question", json["conversation"]["subject"]
  end

  test "create auto-assigns to available operator" do
    # Keep the operator's heartbeat fresh — the fixture's relative timestamp would
    # otherwise go stale (HEARTBEAT_TTL = 90s) during a long full-suite run.
    operator_profiles(:admin_profile).heartbeat!
    post "/widget/v1/conversations",
         params: { initial_message: "Hello!" },
         headers: @headers,
         as: :json

    assert_response :created
    json = JSON.parse(response.body)
    # admin_profile is available (online, recent heartbeat)
    assert json["conversation"]["assigned_operator"].present?
  end

  test "index lists visitor conversations" do
    conv = Conversation.create!(
      account: @account,
      environment: environments(:production),
      visitor_token: @visitor_token,
      visitor_name: "Test Visitor",
      status: :open
    )

    get "/widget/v1/conversations", headers: @headers

    assert_response :success
    json = JSON.parse(response.body)
    ids = json["conversations"].map { |c| c["id"] }
    assert_includes ids, conv.id
  end

  test "messages returns conversation messages with cursor pagination" do
    conv = Conversation.create!(
      account: @account,
      environment: environments(:production),
      visitor_token: @visitor_token,
      visitor_name: "Test",
      status: :open
    )

    3.times do |i|
      conv.conversation_messages.create!(
        account: @account,
        sender_type: "Customer",
        message_type: :text,
        content: "Message #{i}"
      )
    end

    get "/widget/v1/conversations/#{conv.id}/messages",
        params: { limit: 2 },
        headers: @headers

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal 2, json["messages"].length
    assert json["has_more"]
  end

  test "create_message adds message to conversation" do
    conv = Conversation.create!(
      account: @account,
      environment: environments(:production),
      visitor_token: @visitor_token,
      visitor_name: "Test",
      status: :open
    )

    assert_difference "ConversationMessage.count", 1 do
      post "/widget/v1/conversations/#{conv.id}/messages",
           params: { content: "New message" },
           headers: @headers,
           as: :json
    end

    assert_response :created
    json = JSON.parse(response.body)
    assert_equal "New message", json["message"]["content"]
    assert_equal "Customer", json["message"]["sender_type"]
  end

  test "create_message rejects a disallowed attachment type" do
    conv = Conversation.create!(
      account: @account, environment: environments(:production),
      visitor_token: @visitor_token, visitor_name: "Test", status: :open
    )
    evil = Rack::Test::UploadedFile.new(StringIO.new("MZ\x90\x00"), "application/x-msdownload", original_filename: "evil.exe")

    assert_no_difference "ConversationMessage.count" do
      post "/widget/v1/conversations/#{conv.id}/messages",
           params: { content: "hi", attachments: [evil] },
           headers: @headers
    end
    assert_response :unprocessable_entity
  end

  test "mark_read updates cursor" do
    conv = Conversation.create!(
      account: @account,
      environment: environments(:production),
      visitor_token: @visitor_token,
      visitor_name: "Test",
      status: :open
    )

    msg = conv.conversation_messages.create!(
      account: @account,
      sender_type: "User",
      sender_id: users(:admin).id,
      message_type: :text,
      content: "Hello from operator"
    )

    post "/widget/v1/conversations/#{conv.id}/read",
         params: { message_id: msg.id },
         headers: @headers,
         as: :json

    assert_response :success

    cursor = ConversationReadCursor.find_by(conversation: conv, reader_type: "Visitor")
    assert_equal msg.id, cursor.last_read_message_id
  end

  test "rate stores rating on conversation" do
    conv = Conversation.create!(
      account: @account,
      environment: environments(:production),
      visitor_token: @visitor_token,
      visitor_name: "Test",
      status: :resolved
    )

    post "/widget/v1/conversations/#{conv.id}/rate",
         params: { rating: 5, comment: "Great help!" },
         headers: @headers,
         as: :json

    assert_response :success
    conv.reload
    assert_equal 5, conv.rating
    assert_equal "Great help!", conv.rating_comment
  end

  test "cannot access other visitor's conversation" do
    other_conv = conversations(:open_chat) # different visitor_token

    get "/widget/v1/conversations/#{other_conv.id}/messages",
        headers: @headers

    assert_response :not_found
  end
end
