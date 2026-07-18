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

  test "deliveries count delivered messages as successes" do
    messages(:email_one).update!(status: :delivered)

    get "/dashboard/stats", headers: api_key_headers(environments(:production)), as: :json

    assert_response :success
    json = JSON.parse(response.body)
    expected = environments(:production).messages.where(status: [:sent, :delivered]).count
    assert_equal expected, json.dig("deliveries", "total")
    assert_operator json.dig("deliveries", "email_sent"), :>=, 1
  end
end
