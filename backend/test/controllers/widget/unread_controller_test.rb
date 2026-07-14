require "test_helper"

class Widget::UnreadControllerTest < ActionDispatch::IntegrationTest
  setup do
    @account = accounts(:acme)
    @visitor_token = "unread_test_#{SecureRandom.hex(8)}"
    @headers = { "X-Widget-Key" => chat_widget_settings(:acme_settings).widget_key, "X-Visitor-Token" => @visitor_token }
  end

  test "returns unread count" do
    conv = Conversation.create!(
      account: @account,
      environment: environments(:production),
      visitor_token: @visitor_token,
      visitor_name: "Test",
      status: :open
    )

    conv.conversation_messages.create!(
      account: @account,
      sender_type: "User",
      sender_id: users(:admin).id,
      message_type: :text,
      content: "Hello!"
    )

    get "/widget/v1/unread_count", headers: @headers

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal 1, json["count"]
  end

  test "returns zero when no unread messages" do
    get "/widget/v1/unread_count", headers: @headers

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal 0, json["count"]
  end
end
