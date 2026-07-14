require "test_helper"

class ConversationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:admin)
    @headers = auth_headers(@user)
  end

  test "index returns conversations" do
    get "/conversations", headers: @headers

    assert_response :success
    json = JSON.parse(response.body)
    assert json["conversations"].is_a?(Array)
    assert json["total"].is_a?(Integer)
  end

  test "index filters by status" do
    get "/conversations", params: { status: "resolved" }, headers: @headers

    assert_response :success
    json = JSON.parse(response.body)
    json["conversations"].each do |c|
      assert_equal "resolved", c["status"]
    end
  end

  test "index filters by assigned_to=me" do
    get "/conversations", params: { assigned_to: "me" }, headers: @headers

    assert_response :success
    json = JSON.parse(response.body)
    json["conversations"].each do |c|
      assert_equal @user.id, c["assigned_user"]["id"]
    end
  end

  test "index filters by search term" do
    get "/conversations", params: { q: "Friendly", status: "open" }, headers: @headers

    assert_response :success
    json = JSON.parse(response.body)
    assert json["conversations"].any? { |c| c["visitor_name"].include?("Friendly") }
  end

  test "show returns conversation detail" do
    conv = conversations(:open_chat)
    get "/conversations/#{conv.id}", headers: @headers

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal conv.id, json["conversation"]["id"]
    assert json["messages"].is_a?(Array)
  end

  test "messages returns paginated messages" do
    conv = conversations(:open_chat)
    get "/conversations/#{conv.id}/messages", headers: @headers

    assert_response :success
    json = JSON.parse(response.body)
    assert json["messages"].is_a?(Array)
    assert json.key?("has_more")
  end

  test "create_message as operator" do
    conv = conversations(:open_chat)

    assert_difference "ConversationMessage.count", 1 do
      post "/conversations/#{conv.id}/create_message",
           params: { content: "Operator reply" },
           headers: @headers,
           as: :json
    end

    assert_response :created
    json = JSON.parse(response.body)
    assert_equal "User", json["message"]["sender_type"]
  end

  test "create_message as private note" do
    conv = conversations(:open_chat)

    post "/conversations/#{conv.id}/create_message",
         params: { content: "Internal note", private: true },
         headers: @headers,
         as: :json

    assert_response :created
    json = JSON.parse(response.body)
    assert json["message"]["private"]
    assert_equal "note", json["message"]["message_type"]
  end

  test "update conversation status" do
    conv = conversations(:open_chat)
    patch "/conversations/#{conv.id}",
          params: { status: "resolved" },
          headers: @headers,
          as: :json

    assert_response :success
    conv.reload
    assert conv.resolved?
  end

  test "assign conversation" do
    conv = conversations(:pending_chat)
    regular = users(:regular)

    post "/conversations/#{conv.id}/assign",
         params: { user_id: regular.id },
         headers: @headers,
         as: :json

    assert_response :success
    conv.reload
    assert_equal regular.id, conv.assigned_user_id
  end

  test "transfer conversation" do
    conv = conversations(:open_chat)
    regular = users(:regular)

    post "/conversations/#{conv.id}/transfer",
         params: { user_id: regular.id, note: "Better fit" },
         headers: @headers,
         as: :json

    assert_response :success
    conv.reload
    assert_equal regular.id, conv.assigned_user_id
    assert conv.conversation_messages.last.content.include?("transferred")
  end

  test "snooze conversation" do
    conv = conversations(:open_chat)
    snooze_until = 2.hours.from_now.iso8601

    post "/conversations/#{conv.id}/snooze",
         params: { until: snooze_until },
         headers: @headers,
         as: :json

    assert_response :success
    conv.reload
    assert conv.snoozed?
  end

  test "add and remove tag" do
    conv = conversations(:pending_chat)
    tag = conversation_tags(:bug_tag)

    post "/conversations/#{conv.id}/add_tag",
         params: { tag_id: tag.id },
         headers: @headers,
         as: :json

    assert_response :success
    assert conv.conversation_tags.include?(tag)

    delete "/conversations/#{conv.id}/tags/#{tag.id}",
           headers: @headers

    assert_response :success
    assert_not conv.conversation_tags.reload.include?(tag)
  end

  test "search conversations" do
    get "/conversations/search", params: { q: "pricing" }, headers: @headers

    assert_response :success
    json = JSON.parse(response.body)
    assert json["conversations"].is_a?(Array)
  end

  test "stats returns counts" do
    get "/conversations/stats", headers: @headers

    assert_response :success
    json = JSON.parse(response.body)
    assert json.key?("open")
    assert json.key?("pending")
    assert json.key?("snoozed")
  end

  test "cannot access other account conversations" do
    other_conv = conversations(:other_account_chat)
    get "/conversations/#{other_conv.id}", headers: @headers

    assert_response :not_found
  end
end
