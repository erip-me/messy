require "test_helper"

class HelpdeskControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:admin)
    @headers = auth_headers(@user)
  end

  test "stats returns ticket counts" do
    get "/helpdesk/stats", headers: @headers
    assert_response :success
    data = JSON.parse(response.body)

    assert data.key?("open_count")
    assert data.key?("pending_count")
    assert data.key?("resolved_count")
    assert data.key?("closed_count")
    assert data.key?("unassigned_count")
    assert data.key?("tickets_today")
    assert data.key?("tickets_this_week")
    assert data.key?("avg_first_response_seconds")
    assert data.key?("avg_resolution_seconds")
    assert data.key?("per_operator")
  end

  test "stats counts email tickets correctly" do
    get "/helpdesk/stats", headers: @headers
    data = JSON.parse(response.body)

    # We have 2 email tickets in fixtures: email_ticket (open) and email_ticket_resolved (resolved)
    assert_operator data["open_count"], :>=, 1
    assert_operator data["resolved_count"], :>=, 1
  end

  test "stats per_operator includes assigned operators" do
    get "/helpdesk/stats", headers: @headers
    data = JSON.parse(response.body)

    if data["per_operator"].any?
      op = data["per_operator"].first
      assert op.key?("user_id")
      assert op.key?("name")
      assert op.key?("open_count")
      assert op.key?("pending_count")
      assert op.key?("resolved_today")
    end
  end
end
