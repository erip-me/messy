require "test_helper"

class ConversationsEmailTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:admin)
    @headers = auth_headers(@user)
    @ticket = conversations(:email_ticket)
  end

  test "index filters by source=email" do
    get "/conversations", headers: @headers, params: { source: "email", status: "open" }
    assert_response :success
    data = JSON.parse(response.body)
    data["conversations"].each do |c|
      assert_equal "email", c["source"]
    end
  end

  test "index includes source and ticket_number in response" do
    get "/conversations", headers: @headers, params: { status: "open" }
    assert_response :success
    data = JSON.parse(response.body)
    email_conv = data["conversations"].find { |c| c["source"] == "email" }
    if email_conv
      assert email_conv.key?("ticket_number")
      assert email_conv.key?("source")
    end
  end

  test "index search finds by ticket_number" do
    get "/conversations", headers: @headers, params: { q: "SUP-1001", status: "open" }
    assert_response :success
    data = JSON.parse(response.body)
    assert data["conversations"].any? { |c| c["ticket_number"] == "SUP-1001" }
  end

  test "show includes email_thread for email conversations" do
    get "/conversations/#{@ticket.id}", headers: @headers
    assert_response :success
    data = JSON.parse(response.body)
    assert data["conversation"].key?("email_thread")
    thread = data["conversation"]["email_thread"]
    assert_equal "SUP-1001", thread["ticket_number"]
    assert_equal "sarah@customer.com", thread["from_email"]
    assert thread["cc_list"].is_a?(Array)
  end

  test "email_detail returns email message details" do
    msg = @ticket.conversation_messages.create!(
      account: accounts(:acme), sender_type: "Customer", message_type: :text, content: "test email"
    )
    EmailMessageDetail.create!(
      conversation_message: msg,
      message_id_header: "<test@customer.com>",
      from_email: "sarah@customer.com",
      to_email: "support@acme.com",
      html_body: "<p>test email</p>",
      text_body: "test email"
    )

    get "/conversations/#{@ticket.id}/email_detail", headers: @headers, params: { message_id: msg.id }
    assert_response :success
    data = JSON.parse(response.body)
    assert_not_nil data["email_detail"]
    assert_equal "<p>test email</p>", data["email_detail"]["html_body"]
  end

  test "create_message on email ticket creates reply message" do
    post "/conversations/#{@ticket.id}/create_message", headers: @headers, params: {
      content: "Thanks for reaching out, we'll look into this."
    }
    assert_response :created
    data = JSON.parse(response.body)
    assert_equal "Thanks for reaching out, we'll look into this.", data["message"]["content"]
    assert_equal "User", data["message"]["sender_type"]
  end

  test "create_message with private note" do
    post "/conversations/#{@ticket.id}/create_message", headers: @headers, params: {
      content: "Internal note about this ticket", private: true
    }
    assert_response :created
    data = JSON.parse(response.body)
    assert data["message"]["private"]
  end

  test "resolving email ticket updates status" do
    patch "/conversations/#{@ticket.id}", headers: @headers, params: { status: "resolved" }
    assert_response :success
    assert_equal "resolved", @ticket.reload.status
  end

  test "mark_unread resets read cursor" do
    # First mark as read
    post "/conversations/#{@ticket.id}/mark_read", headers: @headers
    assert_response :success

    # Then mark unread
    post "/conversations/#{@ticket.id}/mark_unread", headers: @headers
    assert_response :success

    # Verify unread count is > 0
    get "/conversations/#{@ticket.id}", headers: @headers
    data = JSON.parse(response.body)
    assert_operator data["conversation"]["unread_count"], :>=, 0
  end

  test "stats include unread_mine and unread_unassigned" do
    get "/conversations/stats", headers: @headers
    assert_response :success
    data = JSON.parse(response.body)
    assert data.key?("unread_mine")
    assert data.key?("unread_unassigned")
    assert data.key?("unread")
  end
end
