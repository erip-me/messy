require "test_helper"

class DashboardControllerTest < ActionDispatch::IntegrationTest
  test "stats with api_key returns stats structure" do
    get "/dashboard/stats", headers: api_key_headers(environments(:production)), as: :json

    assert_response :success
    json = JSON.parse(response.body)
    assert json.key?("messages")
    assert json.key?("deliveries")
    assert json.key?("errors")
    assert json.key?("messages_per_day")
    assert json.key?("templates")
    assert json.key?("scope")
    assert json.key?("tags")
    assert json.key?("identification")
  end
end
