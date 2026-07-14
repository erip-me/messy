require "test_helper"

class CustomersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:admin)
    @headers = auth_headers(@user)
  end

  test "show includes unsubscribed_channels" do
    customer = customers(:john)
    customer.unsubscribe_from!("sms")

    get customer_path(customer), headers: @headers
    assert_response :success

    data = JSON.parse(response.body)["customer"]
    assert data["unsubscribed_channels"]["sms"].present?
  end

  test "export returns CSV scoped to the account with custom attribute columns" do
    get export_customers_path, headers: @headers
    assert_response :success
    assert_equal "text/csv", response.media_type
    assert_match(/attachment/, response.headers["Content-Disposition"])

    rows = CSV.parse(response.body, headers: true)
    emails = rows.map { |r| r["email"] }

    # Account scoping: acme customers only, not other_co's
    assert_includes emails, "john@example.com"
    assert_includes emails, "jane@example.com"
    assert_not_includes rows.map { |r| r["last_name"] }, "Other"

    # Custom attribute keys become columns
    assert_includes rows.headers, "role"
    john_row = rows.find { |r| r["email"] == "john@example.com" }
    assert_equal "buyer", john_row["role"]
  end

  test "export honours the search filter" do
    get export_customers_path(q: "jane"), headers: @headers
    assert_response :success

    emails = CSV.parse(response.body, headers: true).map { |r| r["email"] }
    assert_equal ["jane@example.com"], emails
  end

  test "toggle_unsubscribe subscribes and unsubscribes" do
    customer = customers(:john)

    # Unsubscribe
    post toggle_unsubscribe_customer_path(customer),
      params: { channel: "email" }, headers: @headers
    assert_response :success

    data = JSON.parse(response.body)
    assert data["unsubscribed_channels"]["email"].present?
    assert_match(/Unsubscribed/, data["message"])

    # Resubscribe
    post toggle_unsubscribe_customer_path(customer),
      params: { channel: "email" }, headers: @headers
    assert_response :success

    data = JSON.parse(response.body)
    assert_not data["unsubscribed_channels"]["email"]
    assert_match(/Resubscribed/, data["message"])
  end

  test "toggle_unsubscribe rejects invalid channel" do
    customer = customers(:john)

    post toggle_unsubscribe_customer_path(customer),
      params: { channel: "fax" }, headers: @headers
    assert_response :unprocessable_entity
  end

  test "toggle_category_unsubscribe opts in and out of marketing" do
    customer = customers(:john)

    post toggle_category_unsubscribe_customer_path(customer), params: { category: "marketing" }, headers: @headers
    assert_response :success
    assert JSON.parse(response.body)["unsubscribed_categories"]["marketing"].present?
    assert customer.reload.unsubscribed_from_category?("marketing")

    post toggle_category_unsubscribe_customer_path(customer), params: { category: "marketing" }, headers: @headers
    assert_response :success
    assert_not customer.reload.unsubscribed_from_category?("marketing")
  end

  test "unsubscribe_all unsubscribes from all channels" do
    customer = customers(:john)

    post unsubscribe_all_customer_path(customer), headers: @headers
    assert_response :success

    data = JSON.parse(response.body)
    assert_match(/Unsubscribed from all/, data["message"])
    Campaign::CHANNELS.each do |ch|
      assert data["unsubscribed_channels"][ch].present?, "expected #{ch} to be unsubscribed"
    end
  end

  test "unsubscribe_all resubscribes when all already unsubscribed" do
    customer = customers(:john)
    Campaign::CHANNELS.each { |ch| customer.unsubscribe_from!(ch) }

    post unsubscribe_all_customer_path(customer), headers: @headers
    assert_response :success

    data = JSON.parse(response.body)
    assert_match(/Resubscribed to all/, data["message"])
    Campaign::CHANNELS.each do |ch|
      assert_not data["unsubscribed_channels"][ch], "expected #{ch} to be subscribed"
    end
  end

  test "unsubscribe_all preserves non-standard channel unsubscriptions on resubscribe" do
    customer = customers(:john)
    Campaign::CHANNELS.each { |ch| customer.unsubscribe_from!(ch) }
    customer.update!(unsubscribed_channels: customer.unsubscribed_channels.merge("custom" => Time.current.iso8601))

    post unsubscribe_all_customer_path(customer), headers: @headers
    assert_response :success

    data = JSON.parse(response.body)
    assert data["unsubscribed_channels"]["custom"].present?, "expected custom channel to remain unsubscribed"
    Campaign::CHANNELS.each do |ch|
      assert_not data["unsubscribed_channels"][ch], "expected #{ch} to be subscribed"
    end
  end
end
