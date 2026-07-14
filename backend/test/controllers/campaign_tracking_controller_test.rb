require "test_helper"

class CampaignTrackingControllerTest < ActionDispatch::IntegrationTest
  include CampaignLinkSigner

  test "open tracks pixel and enqueues activity" do
    delivery = campaign_deliveries(:sent_delivery)
    original_count = delivery.open_count

    LogCampaignActivityJob.expects(:perform_later).once

    get campaign_track_open_path(token: delivery.tracking_token, format: :png)

    assert_response :success
    delivery.reload
    assert_equal original_count + 1, delivery.open_count
    assert_not_nil delivery.opened_at
  end

  test "open returns transparent gif" do
    delivery = campaign_deliveries(:sent_delivery)
    get campaign_track_open_path(token: delivery.tracking_token, format: :png)

    assert_response :success
    assert_equal "image/gif", response.content_type
  end

  test "open with invalid token still returns gif" do
    get campaign_track_open_path(token: "nonexistent", format: :png)
    assert_response :success
  end

  test "click increments count and redirects to a signed url" do
    delivery = campaign_deliveries(:sent_delivery)
    original_count = delivery.click_count

    LogCampaignActivityJob.expects(:perform_later).once

    url = "https://example.com"
    get campaign_track_click_path(token: delivery.tracking_token, url: url, sig: campaign_link_signature(url))

    assert_response :redirect
    assert_redirected_to url
    delivery.reload
    assert_equal original_count + 1, delivery.click_count
  end

  test "click does not follow a forged/unsigned url (no open redirect)" do
    delivery = campaign_deliveries(:sent_delivery)

    # No signature, or a signature that doesn't match the url, must NOT redirect off-site.
    get campaign_track_click_path(token: delivery.tracking_token, url: "https://evil.example")
    assert_redirected_to "/"

    get campaign_track_click_path(token: delivery.tracking_token, url: "https://evil.example", sig: "deadbeef")
    assert_redirected_to "/"
  end

  test "click with no url redirects to root" do
    delivery = campaign_deliveries(:sent_delivery)
    get campaign_track_click_path(token: delivery.tracking_token)
    assert_response :redirect
  end

  test "unsubscribe opts the customer out of marketing without blocking the channel" do
    delivery = campaign_deliveries(:sent_delivery)
    customer = delivery.customer

    assert_not customer.unsubscribed_from_category?("marketing")

    LogCampaignActivityJob.expects(:perform_later).once

    get campaign_unsubscribe_path(token: delivery.tracking_token)

    assert_response :success
    customer.reload
    assert customer.unsubscribed_from_category?("marketing")
    assert_not customer.unsubscribed_from?("email"), "the channel stays open for transactional/system mail"
  end

  test "unsubscribe with invalid token renders page without error" do
    get campaign_unsubscribe_path(token: "nonexistent")
    assert_response :success
  end

  test "open sets opened_at only on first open" do
    delivery = campaign_deliveries(:sent_delivery)
    delivery.update_columns(opened_at: nil, open_count: 0)

    get campaign_track_open_path(token: delivery.tracking_token, format: :png)
    delivery.reload
    first_opened = delivery.opened_at
    assert_not_nil first_opened
    assert_equal 1, delivery.open_count

    # Second open should not change opened_at but increment count
    get campaign_track_open_path(token: delivery.tracking_token, format: :png)
    delivery.reload
    assert_equal first_opened.to_i, delivery.opened_at.to_i
    assert_equal 2, delivery.open_count
  end

  test "click tracks multiple clicks atomically" do
    delivery = campaign_deliveries(:sent_delivery)
    delivery.update_columns(click_count: 0)

    get campaign_track_click_path(token: delivery.tracking_token, url: "https://a.com")
    get campaign_track_click_path(token: delivery.tracking_token, url: "https://b.com")

    delivery.reload
    assert_equal 2, delivery.click_count
  end

  test "test_unsubscribe renders info page without unsubscribing" do
    customer = customers(:john)

    get campaign_test_unsubscribe_path(email: customer.email, channel: "email", campaign: "My Campaign")

    assert_response :success
    assert_includes response.body, "Test Unsubscribe Link"
    assert_includes response.body, customer.email
    assert_includes response.body, "email"
    assert_includes response.body, "My Campaign"

    customer.reload
    assert_not customer.unsubscribed_from?("email")
  end
end
