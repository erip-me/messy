require "test_helper"

class CampaignsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:admin)
    @headers = auth_headers(@user).merge("X-Environment-Id" => environments(:production).id.to_s)
  end

  test "index returns campaigns with channel and template" do
    get campaigns_path, headers: @headers
    assert_response :success

    data = JSON.parse(response.body)
    assert_kind_of Array, data
    campaign = data.find { |c| c["name"] == "March Newsletter" }
    assert_equal "email", campaign["channel"]
  end

  test "create email campaign with channel and environment" do
    assert_difference -> { Campaign.count }, 1 do
      post campaigns_path, params: {
        name: "New Email Campaign",
        subject: "Test Subject",
        channel: "email",
        content: "<p>Hello</p>"
      }, headers: @headers
    end

    assert_response :created
    campaign = Campaign.last
    assert_equal "email", campaign.channel
    assert_equal environments(:production).id, campaign.environment_id
  end

  test "create sms campaign without subject" do
    assert_difference -> { Campaign.count }, 1 do
      post campaigns_path, params: {
        name: "SMS Blast",
        channel: "sms",
        content: "Hello!"
      }, headers: @headers
    end

    assert_response :created
    assert_equal "sms", Campaign.last.channel
  end

  test "send_campaign validates unsubscribe_url for email" do
    campaign = campaigns(:email_draft)
    campaign.update!(content: "<p>No unsub link here</p>")

    post send_campaign_campaign_path(campaign), headers: @headers
    assert_response :unprocessable_entity

    data = JSON.parse(response.body)
    assert_match(/unsubscribe_url/, data["error"])
  end

  test "send_campaign succeeds with unsubscribe_url present" do
    campaign = campaigns(:email_draft)

    post send_campaign_campaign_path(campaign), headers: @headers
    assert_response :success

    campaign.reload
    assert_equal "sending", campaign.status
  end

  test "send_campaign allows no segment (all customers)" do
    campaign = campaigns(:email_draft)
    campaign.update!(segment: nil)

    post send_campaign_campaign_path(campaign), headers: @headers
    assert_response :success
  end

  test "show includes template in response" do
    campaign = campaigns(:email_draft)
    campaign.update!(template: templates(:welcome))

    get campaign_path(campaign), headers: @headers
    assert_response :success

    data = JSON.parse(response.body)
    assert_equal "Welcome Email", data["template"]["name"]
  end

  # ── send_test ───────────────────────────────────────────────────────────────

  test "send_test delivers email with merge tags resolved" do
    campaign = campaigns(:email_draft)
    customer = customers(:john)

    SesIntegration.any_instance.stubs(:deliver!).once

    post send_test_campaign_path(campaign), params: { customer_id: customer.id }, headers: @headers
    assert_response :success

    message = EmailMessage.last
    assert_equal customer.email, message.to
    assert_match "[TEST]", message.subject
    assert_includes message.body, "John"
  end

  test "send_test resolves custom_attributes as merge tags" do
    campaign = campaigns(:email_draft)
    campaign.update!(content: "<p>Hello {{first_name}}, role: {{role}}</p><a href='{{unsubscribe_url}}'>Unsubscribe</a>")
    customer = customers(:john) # has custom_attributes: { role: "buyer" }

    SesIntegration.any_instance.stubs(:deliver!).once

    post send_test_campaign_path(campaign), params: { customer_id: customer.id }, headers: @headers
    assert_response :success

    message = EmailMessage.last
    assert_includes message.body, "role: buyer"
    assert_includes message.body, "Hello John"
  end

  test "send_test renders empty string for missing custom_attributes" do
    campaign = campaigns(:email_draft)
    campaign.update!(content: "<p>Hello {{first_name}}, city: {{city}}</p><a href='{{unsubscribe_url}}'>Unsubscribe</a>")
    customer = customers(:john) # no "city" in custom_attributes

    SesIntegration.any_instance.stubs(:deliver!).once

    post send_test_campaign_path(campaign), params: { customer_id: customer.id }, headers: @headers
    assert_response :success

    message = EmailMessage.last
    assert_includes message.body, "city: "
    assert_not_includes message.body, "{{city}}"
  end

  test "send_test rejects non-email campaign" do
    campaign = campaigns(:sms_draft)
    post send_test_campaign_path(campaign), params: { customer_id: customers(:john).id }, headers: @headers
    assert_response :unprocessable_entity
  end

  test "send_test rejects unknown customer" do
    campaign = campaigns(:email_draft)
    post send_test_campaign_path(campaign), params: { customer_id: 0 }, headers: @headers
    assert_response :not_found
  end

  test "send_test includes test unsubscribe url with customer email" do
    campaign = campaigns(:email_draft)
    campaign.update!(content: "<p>Hello</p><a href='{{unsubscribe_url}}'>Unsubscribe</a>")
    customer = customers(:john)

    SesIntegration.any_instance.stubs(:deliver!).once

    post send_test_campaign_path(campaign), params: { customer_id: customer.id }, headers: @headers
    assert_response :success

    message = EmailMessage.last
    assert_includes message.body, "test_unsubscribe"
    assert_includes message.body, CGI.escape(customer.email)
    assert_includes message.body, "channel=email"
    assert_not_includes message.body, 'href=\'#\''
  end

  test "send_test uses custom tracking domain when set" do
    account = accounts(:acme)
    account.update!(tracking_domain: "track.acme.com")
    campaign = campaigns(:email_draft)
    campaign.update!(content: "<p>Hello</p><a href='{{unsubscribe_url}}'>Unsubscribe</a>")
    customer = customers(:john)

    SesIntegration.any_instance.stubs(:deliver!).once

    post send_test_campaign_path(campaign), params: { customer_id: customer.id }, headers: @headers
    assert_response :success

    message = EmailMessage.last
    assert_includes message.body, "https://track.acme.com/campaign_track/test_unsubscribe"
  end

  test "send_test falls back to API_URL when no tracking domain" do
    account = accounts(:acme)
    account.update!(tracking_domain: nil)
    campaign = campaigns(:email_draft)
    campaign.update!(content: "<p>Hello</p><a href='{{unsubscribe_url}}'>Unsubscribe</a>")
    customer = customers(:john)

    SesIntegration.any_instance.stubs(:deliver!).once

    post send_test_campaign_path(campaign), params: { customer_id: customer.id }, headers: @headers
    assert_response :success

    message = EmailMessage.last
    assert_not_includes message.body, "track.acme.com"
    assert_includes message.body, "campaign_track/test_unsubscribe"
  end

  test "send_test cannot target campaign from another account" do
    other_campaign = campaigns(:other_campaign)
    post send_test_campaign_path(other_campaign), params: { customer_id: customers(:john).id }, headers: @headers
    assert_response :not_found
  end

  # ── retry_delivery ──────────────────────────────────────────────────────────

  test "retry_delivery requeues a failed delivery" do
    delivery = campaign_deliveries(:pending_delivery)
    delivery.update!(status: "failed", error_message: "Rate limit exceeded")
    campaign = delivery.campaign

    post retry_delivery_campaign_path(campaign), params: { delivery_id: delivery.id }, headers: @headers
    assert_response :success

    delivery.reload
    assert_equal "pending", delivery.status
    assert_nil delivery.error_message
  end

  test "retry_delivery rejects non-failed delivery" do
    delivery = campaign_deliveries(:sent_delivery)
    campaign = delivery.campaign

    post retry_delivery_campaign_path(campaign), params: { delivery_id: delivery.id }, headers: @headers
    assert_response :unprocessable_entity
  end

  # ── deliveries ───────────────────────────────────────────────────────────────

  test "deliveries filtered by unsubscribed returns only recipients who unsubscribed" do
    campaign = campaigns(:sending_campaign)
    delivery = campaign_deliveries(:sent_delivery)
    CustomerActivity.create!(
      account: campaign.account, customer: delivery.customer, environment: campaign.environment,
      activity_type: "campaign_unsubscribed",
      properties: { campaign_id: campaign.id, delivery_id: delivery.id }
    )

    get deliveries_campaign_path(campaign), params: { status: "unsubscribed" }, headers: @headers
    assert_response :success

    data = JSON.parse(response.body)
    assert_equal 1, data["total"]
    assert_equal [delivery.id], data["deliveries"].map { |d| d["id"] }
  end

  # ── retry_all_failed ───────────────────────────────────────────────────────

  test "retry_all_failed requeues all failed deliveries" do
    campaign = campaigns(:sending_campaign)
    campaign_deliveries(:pending_delivery).update!(status: "failed", error_message: "Rate limit")
    campaign_deliveries(:sent_delivery).update!(status: "failed", error_message: "Rate limit", sent_at: nil)

    post retry_all_failed_campaign_path(campaign), headers: @headers
    assert_response :success

    data = JSON.parse(response.body)
    assert_equal 2, data["count"]

    assert campaign.campaign_deliveries.where(status: "failed").count.zero?
  end

  test "retry_all_failed returns error when no failed deliveries" do
    campaign = campaigns(:sending_campaign)

    post retry_all_failed_campaign_path(campaign), headers: @headers
    assert_response :unprocessable_entity
  end

  # ── Tenant isolation ────────────────────────────────────────────────────────

  test "index only returns campaigns for current user's account" do
    get campaigns_path, headers: @headers
    data = JSON.parse(response.body)

    account_ids = data.map { |c| c["account_id"] }.uniq
    assert_equal [accounts(:acme).id], account_ids
    assert_not data.any? { |c| c["name"] == "Other Co Campaign" }
  end

  test "show returns 404 for campaign belonging to another account" do
    other_campaign = campaigns(:other_campaign)
    get campaign_path(other_campaign), headers: @headers
    assert_response :not_found
  end

  test "update cannot modify campaign belonging to another account" do
    other_campaign = campaigns(:other_campaign)
    patch campaign_path(other_campaign), params: { name: "Hijacked" }, headers: @headers
    assert_response :not_found

    other_campaign.reload
    assert_equal "Other Co Campaign", other_campaign.name
  end

  test "destroy cannot delete campaign belonging to another account" do
    other_campaign = campaigns(:other_campaign)
    assert_no_difference -> { Campaign.count } do
      delete campaign_path(other_campaign), headers: @headers
    end
    assert_response :not_found
  end

  test "send_campaign cannot trigger campaign belonging to another account" do
    other_campaign = campaigns(:other_campaign)
    post send_campaign_campaign_path(other_campaign), headers: @headers
    assert_response :not_found

    other_campaign.reload
    assert_equal "draft", other_campaign.status
  end

  test "create rejects segment_id from another account" do
    post campaigns_path, params: {
      name: "Cross-tenant attempt",
      subject: "Test",
      channel: "email",
      content: "<p>Hello</p>",
      segment_id: segments(:other_segment).id
    }, headers: @headers

    assert_response :unprocessable_entity
  end

  test "create rejects environment_id from another account" do
    post campaigns_path, params: {
      name: "Cross-tenant env",
      subject: "Test",
      channel: "email",
      content: "<p>Hello</p>",
      environment_id: environments(:other_env).id
    }, headers: @headers

    assert_response :unprocessable_entity
  end

  # ── API-key access (programmatic campaign management) ───────────────────────

  test "index works with an environment API key" do
    get campaigns_path, headers: api_key_headers(environments(:production))
    assert_response :success
    assert_kind_of Array, JSON.parse(response.body)
  end

  test "index is scoped to the active environment" do
    # Same account, different environment — must not appear under production.
    staging_campaign = accounts(:acme).campaigns.create!(
      name: "Staging Only", subject: "x", channel: "email", status: "draft",
      environment: environments(:staging)
    )

    get campaigns_path, headers: @headers # X-Environment-Id => production
    names = JSON.parse(response.body).map { |c| c["name"] }
    assert_includes names, "March Newsletter"          # production campaign
    assert_not_includes names, "Staging Only"          # other environment

    # Switching the environment header surfaces the staging campaign instead.
    get campaigns_path, headers: auth_headers(@user).merge("X-Environment-Id" => environments(:staging).id.to_s)
    names = JSON.parse(response.body).map { |c| c["name"] }
    assert_includes names, "Staging Only"
    assert_not_includes names, "March Newsletter"
  end

  test "create with an API key builds a draft scoped to the key's account and environment" do
    assert_difference -> { Campaign.count }, 1 do
      post campaigns_path, params: {
        name: "Boost Launch (via API)",
        subject: "Boost is here",
        channel: "email",
        template_id: templates(:welcome).id,
        segment_id: segments(:active_buyers).id
      }, headers: api_key_headers(environments(:production))
    end

    assert_response :created
    body = JSON.parse(response.body)
    assert_equal "draft", body["status"]

    created = Campaign.last
    assert_equal accounts(:acme).id, created.account_id
    # environment_id defaults to the API key's environment when not supplied.
    assert_equal environments(:production).id, created.environment_id
    assert_equal segments(:active_buyers).id, created.segment_id
    assert_equal templates(:welcome).id, created.template_id
  end

  test "API key cannot create a campaign targeting another account's segment" do
    post campaigns_path, params: {
      name: "Cross-tenant via key",
      subject: "Test",
      channel: "email",
      content: "<p>Hello</p>",
      segment_id: segments(:other_segment).id
    }, headers: api_key_headers(environments(:production))

    assert_response :unprocessable_entity
  end

  test "campaigns require authentication" do
    get campaigns_path
    assert_response :unauthorized
  end
end
