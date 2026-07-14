class SendCampaignJob < ApplicationJob
  queue_as :campaigns

  BATCH_SIZE = 1000
  SENDS_PER_SECOND = 10

  def perform(campaign_id)
    campaign = Campaign.find_by(id: campaign_id)
    return unless campaign && campaign.status == 'sending'

    customers = resolve_customers(campaign)
    environment = campaign.environment
    active_rules = environment.rules.where(active: true).to_a
    now = Time.current

    customers.select(:id, :email).find_in_batches(batch_size: BATCH_SIZE) do |batch|
      rows = batch.map do |customer|
        check = environment.check_rules_for_channel?(campaign.channel, customer.email, preloaded_rules: active_rules)
        passed = check[:result] == :passed
        {
          campaign_id: campaign.id,
          account_id: campaign.account_id,
          customer_id: customer.id,
          email: customer.email,
          channel: campaign.channel,
          status: passed ? 'pending' : 'rejected',
          error_message: passed ? nil : check[:reason],
          tracking_token: SecureRandom.hex(32),
          created_at: now,
          updated_at: now
        }
      end

      CampaignDelivery.insert_all(rows) if rows.any?
    end

    count = campaign.campaign_deliveries.where(status: 'pending').count
    campaign.update_column(:recipient_count, count)

    if count.zero?
      campaign.update_columns(status: 'sent', sent_at: Time.current)
      return
    end

    # Stagger delivery jobs to stay under SES rate limits
    base_time = Time.current
    offset_seconds = 0
    campaign.campaign_deliveries.where(status: 'pending').in_batches(of: BATCH_SIZE) do |batch|
      ids = batch.pluck(:id)
      jobs = ids.each_slice(SENDS_PER_SECOND).with_index.flat_map do |slice, i|
        slice.map do |id|
          job = SendCampaignDeliveryJob.new(id)
          delay = offset_seconds + i
          job.scheduled_at = base_time + delay.seconds if delay > 0
          job
        end
      end
      ActiveJob.perform_all_later(jobs)
      offset_seconds += (ids.size.to_f / SENDS_PER_SECOND).ceil
    end
  rescue => e
    campaign&.update_columns(status: 'failed')
    raise e
  end

  private

  def resolve_customers(campaign)
    # Campaigns are marketing: skip the hard channel block AND anyone who opted
    # out of marketing (e.g. via a drip/campaign unsubscribe link).
    customers = campaign.account.customers
      .subscribed_to_channel(campaign.channel)
      .subscribed_to_category(Customer::MARKETING_CATEGORY)

    if campaign.segment
      SegmentEvaluator.new(customers, campaign.segment.conditions).evaluate
    else
      customers
    end
  end
end
