require "test_helper"

class SegmentsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:admin)
    @headers = auth_headers(@user)
  end

  # ── Tenant isolation ────────────────────────────────────────────────────────

  test "index only returns segments for current user's account" do
    get segments_path, headers: @headers
    assert_response :success

    data = JSON.parse(response.body)
    names = data.map { |s| s["name"] }
    assert_includes names, "Active Buyers"
    assert_includes names, "All Customers"
    assert_not_includes names, "Other Co Segment"
  end

  test "show returns error for segment belonging to another account" do
    get segment_path(segments(:other_segment)), headers: @headers
    assert_response :not_found
  end

  test "update cannot modify segment belonging to another account" do
    other_segment = segments(:other_segment)
    patch segment_path(other_segment), params: { name: "Hijacked" }, headers: @headers
    assert_response :not_found

    other_segment.reload
    assert_equal "Other Co Segment", other_segment.name
  end

  test "destroy cannot delete segment belonging to another account" do
    assert_no_difference -> { Segment.count } do
      delete segment_path(segments(:other_segment)), headers: @headers
    end
    assert_response :not_found
  end

  test "preview only evaluates against current account customers" do
    # Use a condition that would match customers across accounts
    post preview_segments_path, params: {
      conditions: {
        operator: "and",
        conditions: [
          { attribute: "email", operator: "contains", value: "@example.com" }
        ]
      }
    }, headers: @headers

    assert_response :success
    data = JSON.parse(response.body)

    # Acme has john, jane, and recipient @example.com; other_co has john@example.com
    # Should only return acme's customers (3), not other_co's (1)
    assert_equal 3, data["count"]
    sample_ids = data["sample"].map { |c| c["id"] }
    assert_not_includes sample_ids, customers(:other_customer).id
  end

  test "preview honors nested conditions instead of matching everyone" do
    # Only john has custom.role == buyer; jane and recipient do not. A regression
    # that drops the nested conditions array would match all 3 acme customers.
    post preview_segments_path, params: {
      conditions: {
        operator: "and",
        conditions: [
          { attribute: "custom.role", operator: "equals", value: "buyer" }
        ]
      }
    }, headers: @headers

    assert_response :success
    data = JSON.parse(response.body)
    assert_equal 1, data["count"]
    assert_equal [customers(:john).id], data["sample"].map { |c| c["id"] }
  end

  test "create scopes segment to current account" do
    assert_difference -> { Segment.count }, 1 do
      post segments_path, params: {
        name: "New Segment",
        conditions: { operator: "and", conditions: [] }
      }, headers: @headers
    end

    assert_response :created
    assert_equal accounts(:acme).id, Segment.last.account_id
  end

  test "create persists the nested conditions instead of dropping them" do
    post segments_path, params: {
      name: "Buyers",
      conditions: {
        operator: "and",
        conditions: [
          { attribute: "custom.role", operator: "equals", value: "buyer" }
        ]
      }
    }, headers: @headers

    assert_response :created
    saved = Segment.last.conditions
    assert_equal "and", saved["operator"]
    assert_equal 1, saved["conditions"].length
    assert_equal "custom.role", saved["conditions"][0]["attribute"]
    assert_equal "buyer", saved["conditions"][0]["value"]
  end

  # ── API-key access ──────────────────────────────────────────────────────────

  test "index works with an environment API key and stays account-scoped" do
    get segments_path, headers: api_key_headers(environments(:production))
    assert_response :success

    names = JSON.parse(response.body).map { |s| s["name"] }
    assert_includes names, "Active Buyers"
    assert_not_includes names, "Other Co Segment"
  end

  test "an API key only sees its own account's segments" do
    get segments_path, headers: api_key_headers(environments(:other_env))
    assert_response :success

    names = JSON.parse(response.body).map { |s| s["name"] }
    assert_includes names, "Other Co Segment"
    assert_not_includes names, "Active Buyers"
  end

  test "segments require authentication" do
    get segments_path
    assert_response :unauthorized
  end
end
