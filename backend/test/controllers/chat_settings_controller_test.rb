require "test_helper"

class ChatSettingsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:admin)
    @headers = auth_headers(@user)
  end

  test "show returns widget settings and tags" do
    get "/chat_settings", headers: @headers

    assert_response :success
    json = JSON.parse(response.body)
    assert json["widget_settings"].present?
    assert json["tags"].is_a?(Array)
    assert_equal "#3B86E4", json["widget_settings"]["primary_color"]
  end

  test "update widget settings" do
    patch "/chat_settings",
          params: { widget_settings: { primary_color: "#FF0000", greeting_message: "Welcome!" } },
          headers: @headers,
          as: :json

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal "#FF0000", json["widget_settings"]["primary_color"]
    assert_equal "Welcome!", json["widget_settings"]["greeting_message"]
  end
end
