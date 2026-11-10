require "test_helper"

class CampaignDeliveryTest < ActiveSupport::TestCase
  test "maybe_complete_campaign marks campaign sent when no pending deliveries remain" do
    campaign = campaigns(:sending_campaign)
    assert_equal "sending", campaign.status

    # Mark all deliveries as sent via update! (triggers after_commit)
    campaign.campaign_deliveries.each do |d|
      d.update!(status: "sent", sent_at: Time.current)
    end

    campaign.reload
    assert_equal "sent", campaign.status
    assert_not_nil campaign.sent_at
  end

  # Parallel delivery jobs can't see each other's uncommitted rows, so the check
  # only means something after commit. Inside the transaction it must not run.
  test "maybe_complete_campaign waits for the delivery's transaction to commit" do
    campaign = campaigns(:sending_campaign)

    CampaignDelivery.transaction do
      campaign.campaign_deliveries.each { |d| d.update!(status: "sent", sent_at: Time.current) }
      assert_equal "sending", campaign.reload.status
    end

    assert_equal "sent", campaign.reload.status
  end

  test "the last delivery's broadcast tells the page the campaign is sent" do
    campaign = campaigns(:sending_campaign)
    statuses = []
    ActionCable.server.stubs(:broadcast).with { |_ch, payload| statuses << payload[:campaign_status]; true }

    campaign.campaign_deliveries.each { |d| d.update!(status: "sent", sent_at: Time.current) }

    assert_equal "sent", statuses.last
  end

  test "maybe_complete_campaign does not fire while pending deliveries exist" do
    campaign = campaigns(:sending_campaign)
    pending = campaign_deliveries(:pending_delivery)
    sent = campaign_deliveries(:sent_delivery)

    # Mark one as sent — but one is still pending
    sent.update!(status: "sent") unless sent.status == "sent"
    # Force re-save to trigger callback
    sent.update!(sent_at: Time.current)

    campaign.reload
    assert_equal "sending", campaign.status
  end

  test "maybe_complete_campaign does not fire when campaign is not sending" do
    campaign = campaigns(:sending_campaign)
    campaign.update_columns(status: "draft")

    campaign.campaign_deliveries.each do |d|
      d.update!(status: "sent", sent_at: Time.current)
    end

    campaign.reload
    assert_equal "draft", campaign.status
  end

  test "log_activity! enqueues LogCampaignActivityJob" do
    delivery = campaign_deliveries(:sent_delivery)
    LogCampaignActivityJob.expects(:perform_later).with(
      account_id: delivery.account_id,
      customer_id: delivery.customer_id,
      environment_id: delivery.campaign.environment_id,
      activity_type: "campaign_sent",
      properties: {
        campaign_id: delivery.campaign_id,
        campaign_name: delivery.campaign.name,
        delivery_id: delivery.id,
        channel: "email"
      }
    ).once

    delivery.log_activity!("campaign_sent", channel: "email")
  end

  test "log_activity! does nothing without customer" do
    delivery = campaign_deliveries(:sent_delivery)
    delivery.customer_id = nil

    LogCampaignActivityJob.expects(:perform_later).never
    delivery.log_activity!("campaign_sent")
  end

  test "log_activity! does nothing without environment" do
    delivery = campaign_deliveries(:sent_delivery)
    delivery.campaign.environment_id = nil

    LogCampaignActivityJob.expects(:perform_later).never
    delivery.log_activity!("campaign_sent")
  end
end
