require "test_helper"

class Widget::OfflineControllerTest < ActionDispatch::IntegrationTest
  setup do
    @account = accounts(:acme)
    @headers = { "X-Widget-Key" => chat_widget_settings(:acme_settings).widget_key, "X-Visitor-Token" => "offline_visitor" }
  end

  test "submits offline form" do
    post "/widget/v1/offline",
         params: { name: "Jane", email: "jane@visitor.com", message: "I need help" },
         headers: @headers,
         as: :json

    assert_response :success
    json = JSON.parse(response.body)
    assert json["success"]
  end

  test "requires name, email, and message" do
    post "/widget/v1/offline",
         params: { name: "Jane" },
         headers: @headers,
         as: :json

    assert_response :unprocessable_entity
  end
end
