require "test_helper"

class SendCampaignDeliveryJobTest < ActiveJob::TestCase
  test "delivers email campaign via integration" do
    delivery = campaign_deliveries(:pending_delivery)

    SesIntegration.any_instance.expects(:deliver!).once

    SendCampaignDeliveryJob.new.perform(delivery.id)

    delivery.reload
    assert_equal "sent", delivery.status
    assert_not_nil delivery.sent_at
  end

  test "uses the campaign's sending identity as the from address" do
    delivery = campaign_deliveries(:pending_delivery)
    identity = delivery.campaign.account.sending_identities.create!(from_name: "Peter", from_email: "peter@lalaaji.com")
    delivery.campaign.update!(sending_identity: identity)

    captured = nil
    SesIntegration.any_instance.expects(:deliver!).with { |_msg, **kw| captured = kw[:from]; true }.once
    SendCampaignDeliveryJob.new.perform(delivery.id)

    assert_equal "Peter <peter@lalaaji.com>", captured
  end

  test "delivers sms campaign via integration" do
    campaign = campaigns(:sms_draft)
    campaign.update!(status: "sending")

    delivery = campaign.campaign_deliveries.create!(
      account: accounts(:acme),
      customer: customers(:john),
      email: customers(:john).email,
      channel: "sms",
      status: "pending",
      tracking_token: SecureRandom.hex(32)
    )

    TwilioIntegration.any_instance.expects(:deliver!).once

    SendCampaignDeliveryJob.new.perform(delivery.id)

    delivery.reload
    assert_equal "sent", delivery.status
  end

  test "marks delivery failed on error" do
    delivery = campaign_deliveries(:pending_delivery)
    SesIntegration.any_instance.expects(:deliver!).raises(StandardError, "SMTP error")

    assert_raises(StandardError) do
      SendCampaignDeliveryJob.new.perform(delivery.id)
    end

    delivery.reload
    assert_equal "failed", delivery.status
    assert_equal "SMTP error", delivery.error_message
  end

  test "skips already sent deliveries" do
    delivery = campaign_deliveries(:sent_delivery)
    SesIntegration.any_instance.expects(:deliver!).never

    SendCampaignDeliveryJob.new.perform(delivery.id)
  end

  test "calls LogCampaignActivityJob after delivery" do
    delivery = campaign_deliveries(:pending_delivery)
    SesIntegration.any_instance.expects(:deliver!).once
    LogCampaignActivityJob.expects(:perform_later).once

    SendCampaignDeliveryJob.new.perform(delivery.id)
  end

  test "renders liquid template variables" do
    delivery = campaign_deliveries(:pending_delivery)

    SesIntegration.any_instance.expects(:deliver!).with do |msg|
      msg.html.include?("john@example.com") || msg.html.include?(delivery.tracking_token)
    end

    SendCampaignDeliveryJob.new.perform(delivery.id)
  end

  test "includes real unsubscribe url with tracking token" do
    campaign = campaigns(:sending_campaign)
    campaign.update!(content: "<p>Hi</p><a href='{{unsubscribe_url}}'>Unsub</a>")
    delivery = campaign_deliveries(:pending_delivery)
    delivered_msg = nil

    SesIntegration.any_instance.stubs(:deliver!).with { |msg| delivered_msg = msg; true }

    SendCampaignDeliveryJob.new.perform(delivery.id)

    assert_not_nil delivered_msg
    # The unsubscribe URL is click-tracked, so it appears URL-encoded inside the click redirect
    unsubscribe_path = "campaign_track/#{delivery.tracking_token}/unsubscribe"
    assert delivered_msg.html.include?(unsubscribe_path) || delivered_msg.html.include?(CGI.escape(unsubscribe_path)),
      "Expected HTML to contain unsubscribe URL (raw or encoded)"
  end

  test "renders custom_attributes as merge tags" do
    campaign = campaigns(:sending_campaign)
    campaign.update!(content: "<p>Hi {{first_name}}, role: {{role}}</p><a href='{{unsubscribe_url}}'>Unsubscribe</a>")

    delivery = campaign_deliveries(:pending_delivery)
    # john fixture has custom_attributes: { role: "buyer" }

    SesIntegration.any_instance.expects(:deliver!).with do |msg|
      msg.html.include?("Hi John") && msg.html.include?("role: buyer")
    end

    SendCampaignDeliveryJob.new.perform(delivery.id)
  end

  test "completing last delivery marks campaign as sent" do
    campaign = campaigns(:sending_campaign)
    assert_equal "sending", campaign.status

    # Mark the sent_delivery as done (already sent in fixture)
    sent = campaign_deliveries(:sent_delivery)
    sent.update_columns(status: "sent") unless sent.status == "sent"

    # Now deliver the pending one — this should complete the campaign
    pending = campaign_deliveries(:pending_delivery)
    SesIntegration.any_instance.expects(:deliver!).once

    SendCampaignDeliveryJob.new.perform(pending.id)

    pending.reload
    assert_equal "sent", pending.status

    campaign.reload
    assert_equal "sent", campaign.status
    assert_not_nil campaign.sent_at
  end

  # ── Rate limit handling ─────────────────────────────────────────────────────

  test "raises RateLimitError on rate limit and does not mark delivery as failed" do
    delivery = campaign_deliveries(:pending_delivery)
    SesIntegration.any_instance.expects(:deliver!).raises(StandardError, "Maximum sending rate exceeded.")

    assert_raises(SendCampaignDeliveryJob::RateLimitError) do
      SendCampaignDeliveryJob.new.perform(delivery.id)
    end

    delivery.reload
    assert_equal "pending", delivery.status
    assert_nil delivery.error_message
  end

  test "raises RateLimitError on throttle error" do
    delivery = campaign_deliveries(:pending_delivery)
    SesIntegration.any_instance.expects(:deliver!).raises(StandardError, "Throttling: Too many requests")

    assert_raises(SendCampaignDeliveryJob::RateLimitError) do
      SendCampaignDeliveryJob.new.perform(delivery.id)
    end

    delivery.reload
    assert_equal "pending", delivery.status
  end

  test "does not treat non-rate-limit errors as RateLimitError" do
    delivery = campaign_deliveries(:pending_delivery)
    SesIntegration.any_instance.expects(:deliver!).raises(StandardError, "Invalid email address")

    assert_raises(StandardError) do
      SendCampaignDeliveryJob.new.perform(delivery.id)
    end

    delivery.reload
    assert_equal "failed", delivery.status
    assert_equal "Invalid email address", delivery.error_message
  end

  # ── Tracking domain ──────────────────────────────────────────────────────────

  test "uses custom tracking domain for all tracking URLs" do
    accounts(:acme).update!(tracking_domain: "track.acme.com")
    delivery = campaign_deliveries(:pending_delivery)
    delivered_msg = nil

    SesIntegration.any_instance.stubs(:deliver!).with { |msg| delivered_msg = msg; true }

    SendCampaignDeliveryJob.new.perform(delivery.id)

    assert_not_nil delivered_msg
    assert_includes delivered_msg.html, "https://track.acme.com/campaign_track/#{delivery.tracking_token}/open.png"
    assert_includes delivered_msg.html, "https://track.acme.com/campaign_track/#{delivery.tracking_token}/click"
    assert delivered_msg.html.include?("track.acme.com/campaign_track/#{delivery.tracking_token}/unsubscribe") ||
      delivered_msg.html.include?(CGI.escape("track.acme.com/campaign_track/#{delivery.tracking_token}/unsubscribe"))
  end

  test "falls back to API_URL when no tracking domain set" do
    accounts(:acme).update!(tracking_domain: nil)
    delivery = campaign_deliveries(:pending_delivery)
    delivered_msg = nil

    SesIntegration.any_instance.stubs(:deliver!).with { |msg| delivered_msg = msg; true }

    SendCampaignDeliveryJob.new.perform(delivery.id)

    assert_not_nil delivered_msg
    assert_not_includes delivered_msg.html, "track.acme.com"
    api_url = ENV.fetch("API_URL", "http://localhost:3300")
    assert_includes delivered_msg.html, "#{api_url}/campaign_track/#{delivery.tracking_token}/open.png"
  end

  # ── Campaign completion ────────────────────────────────────────────────────

  test "failed delivery does not prevent campaign completion" do
    campaign = campaigns(:sending_campaign)

    # Mark sent_delivery as sent
    campaign_deliveries(:sent_delivery).update_columns(status: "sent")

    # Fail the pending one
    pending = campaign_deliveries(:pending_delivery)
    SesIntegration.any_instance.expects(:deliver!).raises(StandardError, "error")

    assert_raises(StandardError) do
      SendCampaignDeliveryJob.new.perform(pending.id)
    end

    pending.reload
    assert_equal "failed", pending.status

    campaign.reload
    assert_equal "sent", campaign.status
  end
end
