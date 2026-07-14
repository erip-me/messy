require "test_helper"

class Widget::ConfigControllerTest < ActionDispatch::IntegrationTest
  setup do
    @account = accounts(:acme)
    @widget_key = chat_widget_settings(:acme_settings).widget_key
  end

  test "returns widget config with online operators" do
    get "/widget/v1/config",
        headers: { "X-Widget-Key" => @widget_key }

    assert_response :success
    json = JSON.parse(response.body)
    assert json["settings"].present?
    assert_equal "#3B86E4", json["settings"]["primary_color"]
    assert_equal "bottom-right", json["settings"]["position"]
    assert json.key?("operators_online")
    assert_kind_of Array, json["tags"]
    assert json.key?("is_within_business_hours")
  end

  test "returns quick reply tags" do
    get "/widget/v1/config",
        headers: { "X-Widget-Key" => @widget_key }

    json = JSON.parse(response.body)
    tag_names = json["tags"].map { |t| t["name"] }
    assert_includes tag_names, "I need help"
    assert_includes tag_names, "Pricing question"
    assert_not_includes tag_names, "Bug report" # not a quick reply
  end

  test "sets visitor token cookie" do
    get "/widget/v1/config",
        headers: { "X-Widget-Key" => @widget_key }

    assert_response :success
    set_cookie = response.headers["Set-Cookie"]
    assert set_cookie.present?
    assert_match(/messy_visitor_token/, set_cookie.to_s)
  end

  test "returns 404 when chat not enabled" do
    # other_co has chat_enabled: false
    other_widget_key = chat_widget_settings(:other_settings).widget_key

    get "/widget/v1/config",
        headers: { "X-Widget-Key" => other_widget_key }

    assert_response :not_found
  end

  test "returns 401 with no widget key" do
    get "/widget/v1/config"

    assert_response :unauthorized
  end

  test "returns 401 with invalid widget key" do
    get "/widget/v1/config",
        headers: { "X-Widget-Key" => "nonexistent_key" }

    assert_response :not_found
  end
end
