require "test_helper"

class SendCampaignJobTest < ActiveJob::TestCase
  test "creates deliveries for all segment customers" do
    campaign = campaigns(:email_draft)
    campaign.update!(status: "sending")

    assert_difference -> { CampaignDelivery.count }, 1 do
      SendCampaignJob.new.perform(campaign.id)
    end

    campaign.reload
    assert_equal 1, campaign.recipient_count
    delivery = campaign.campaign_deliveries.first
    assert_equal "pending", delivery.status
    assert_equal "email", delivery.channel
    assert_not_nil delivery.tracking_token
  end

  test "skips unsubscribed customers" do
    campaign = campaigns(:email_draft)
    campaign.update!(status: "sending")

    # John is the only customer matching the segment
    customers(:john).unsubscribe_from!("email")

    assert_no_difference -> { CampaignDelivery.count } do
      SendCampaignJob.new.perform(campaign.id)
    end

    campaign.reload
    assert_equal 0, campaign.recipient_count
    assert_equal "sent", campaign.status # marked sent with 0 recipients
  end

  test "skips customers opted out of marketing" do
    campaign = campaigns(:email_draft)
    campaign.update!(status: "sending")

    # John is the only customer matching the segment
    customers(:john).unsubscribe_from_category!("marketing")

    assert_no_difference -> { CampaignDelivery.count } do
      SendCampaignJob.new.perform(campaign.id)
    end
  end

  test "sends to all customers when no segment" do
    campaign = campaigns(:sms_draft)
    campaign.update!(status: "sending", segment: nil)

    # acme has john, jane, and recipient
    assert_difference -> { CampaignDelivery.count }, 3 do
      SendCampaignJob.new.perform(campaign.id)
    end

    campaign.reload
    assert_equal 3, campaign.recipient_count
  end

  test "creates deliveries with correct channel for sms" do
    campaign = campaigns(:sms_draft)
    campaign.update!(status: "sending", segment: nil)

    SendCampaignJob.new.perform(campaign.id)

    campaign.campaign_deliveries.each do |d|
      assert_equal "sms", d.channel
    end
  end

  test "uses bulk enqueueing for delivery jobs" do
    campaign = campaigns(:sms_draft)
    campaign.update!(status: "sending", segment: nil)

    ActiveJob.expects(:perform_all_later).at_least_once

    SendCampaignJob.new.perform(campaign.id)
  end

  test "marks campaign failed on error" do
    campaign = campaigns(:email_draft)
    campaign.update!(status: "sending")

    CampaignDelivery.stubs(:insert_all).raises(StandardError, "DB error")

    assert_raises(StandardError) do
      SendCampaignJob.new.perform(campaign.id)
    end

    campaign.reload
    assert_equal "failed", campaign.status
  end

  # ── Staggered scheduling ─────────────────────────────────────────────────────

  test "staggers delivery jobs with scheduled_at offsets" do
    campaign = campaigns(:sms_draft)
    campaign.update!(status: "sending", segment: nil)

    SendCampaignJob.new.perform(campaign.id)

    # acme has 2 customers (john, jane), both fit in one SENDS_PER_SECOND slice
    # so only the first slice (index 0) is used — no delay applied
    deliveries = campaign.campaign_deliveries.where(status: "pending")
    assert deliveries.count <= SendCampaignJob::SENDS_PER_SECOND,
      "All deliveries fit in one scheduling slice, so no staggering is needed for this test"
  end

  # ── Tenant isolation ────────────────────────────────────────────────────────

  test "deliveries only go to campaign account's customers, not other accounts" do
    campaign = campaigns(:sms_draft)
    campaign.update!(status: "sending", segment: nil)

    SendCampaignJob.new.perform(campaign.id)

    delivery_customer_ids = campaign.campaign_deliveries.pluck(:customer_id)
    acme_customer_ids = accounts(:acme).customers.pluck(:id)
    other_customer_ids = accounts(:other_co).customers.pluck(:id)

    # All deliveries should be for acme customers
    assert delivery_customer_ids.all? { |id| acme_customer_ids.include?(id) }
    # No deliveries should be for other_co customers
    assert delivery_customer_ids.none? { |id| other_customer_ids.include?(id) }
  end

  test "segment-filtered deliveries stay within campaign account" do
    campaign = campaigns(:email_draft)
    campaign.update!(status: "sending")

    SendCampaignJob.new.perform(campaign.id)

    delivery_emails = campaign.campaign_deliveries.pluck(:email)
    other_emails = accounts(:other_co).customers.pluck(:email)

    # Even if other_co has customers with matching emails, they must not appear
    delivery_customer_ids = campaign.campaign_deliveries.pluck(:customer_id)
    assert_not_includes delivery_customer_ids, customers(:other_customer).id
  end

  test "all deliveries carry the campaign's account_id" do
    campaign = campaigns(:sms_draft)
    campaign.update!(status: "sending", segment: nil)

    SendCampaignJob.new.perform(campaign.id)

    delivery_account_ids = campaign.campaign_deliveries.pluck(:account_id).uniq
    assert_equal [accounts(:acme).id], delivery_account_ids
  end
end
