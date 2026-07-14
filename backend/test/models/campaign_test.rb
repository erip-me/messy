require "test_helper"

class CampaignTest < ActiveSupport::TestCase
  test "valid email campaign requires subject" do
    c = Campaign.new(account: accounts(:acme), name: "Test", channel: "email", status: "draft")
    assert_not c.valid?
    assert_includes c.errors[:subject], "can't be blank"
  end

  test "sms campaign does not require subject" do
    c = Campaign.new(
      account: accounts(:acme), name: "SMS Test",
      channel: "sms", status: "draft"
    )
    assert c.valid?, c.errors.full_messages.join(", ")
  end

  test "validates channel inclusion" do
    c = Campaign.new(account: accounts(:acme), name: "Bad", channel: "fax", status: "draft")
    assert_not c.valid?
    assert_includes c.errors[:channel], "is not included in the list"
  end

  test "belongs to template optionally" do
    c = campaigns(:email_draft)
    assert_nil c.template
    c.template = templates(:welcome)
    assert c.save
  end

  test "belongs to environment optionally" do
    c = campaigns(:email_draft)
    assert_equal environments(:production), c.environment
  end

  test "channel_integration resolves from environment" do
    c = campaigns(:email_draft)
    assert_equal integrations(:ses), c.channel_integration
  end

  test "channel_integration resolves sms integration" do
    c = campaigns(:sms_draft)
    assert_equal integrations(:twilio), c.channel_integration
  end

  test "stats returns correct counts with grouped query" do
    c = campaigns(:sending_campaign)
    stats = c.stats
    assert_equal 2, stats[:total]
    assert_equal 1, stats[:sent]
    assert_equal 1, stats[:pending]
    assert_equal 0, stats[:failed]
    assert_kind_of Numeric, stats[:open_rate]
  end

  test "stats returns zeros for campaign with no deliveries" do
    c = campaigns(:email_draft)
    stats = c.stats
    assert_equal({ total: 0, sent: 0, failed: 0, pending: 0, rejected: 0, open_rate: 0, unsubscribed: 0 }, stats)
  end

  test "stats counts unsubscribe activities attributed to the campaign" do
    c = campaigns(:sending_campaign)
    cust = customers(:john)
    CustomerActivity.create!(
      account: c.account, customer: cust, environment: c.environment,
      activity_type: 'campaign_unsubscribed', properties: { campaign_id: c.id }
    )
    CustomerActivity.create!(
      account: c.account, customer: cust, environment: c.environment,
      activity_type: 'campaign_opened', properties: { campaign_id: c.id }
    )
    assert_equal 1, c.stats[:unsubscribed]
  end

  test "unsubscribed count is per-person, not per raw event" do
    c = campaigns(:sending_campaign)
    cust = customers(:john)
    # Same person, several unsubscribe events (scanner prefetch / repeat clicks).
    3.times do
      CustomerActivity.create!(
        account: c.account, customer: cust, environment: c.environment,
        activity_type: 'campaign_unsubscribed', properties: { campaign_id: c.id }
      )
    end
    assert_equal 1, c.stats[:unsubscribed]
    assert_equal 1, Campaign.stats_for([c])[c.id][:unsubscribed]
  end

  test "all_delivered? returns false when pending deliveries exist" do
    c = campaigns(:sending_campaign)
    assert_not c.all_delivered?
  end

  test "all_delivered? returns true when no pending deliveries remain" do
    c = campaigns(:sending_campaign)
    c.campaign_deliveries.update_all(status: "sent")
    assert c.all_delivered?
  end

  test "all_delivered? returns false for campaign with no deliveries" do
    c = campaigns(:email_draft)
    assert_not c.all_delivered?
  end

  # ── Tenant isolation: cross-account references ──────────────────────────────

  test "rejects segment from another account" do
    c = campaigns(:email_draft)
    c.segment = segments(:other_segment)
    assert_not c.valid?
    assert_includes c.errors[:segment], "must belong to the same account"
  end

  test "rejects template from another account" do
    other_template = Template.create!(
      account: accounts(:other_co),
      environment: environments(:other_env),
      name: "Other Template",
      trigger: "other.trigger",
      channel: "email",
      subject: "Other",
      body: "<p>Other</p>",
      body_format: "html"
    )
    c = campaigns(:email_draft)
    c.template = other_template
    assert_not c.valid?
    assert_includes c.errors[:template], "must belong to the same account"
  end

  test "rejects environment from another account" do
    c = campaigns(:email_draft)
    c.environment = environments(:other_env)
    assert_not c.valid?
    assert_includes c.errors[:environment], "must belong to the same account"
  end

  test "accepts segment from same account" do
    c = campaigns(:email_draft)
    c.segment = segments(:active_buyers)
    assert c.valid?, c.errors.full_messages.join(", ")
  end

  test "accepts nil segment" do
    c = campaigns(:email_draft)
    c.segment = nil
    assert c.valid?, c.errors.full_messages.join(", ")
  end
end
