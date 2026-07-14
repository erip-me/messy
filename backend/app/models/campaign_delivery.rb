class CampaignDelivery < ApplicationRecord
  belongs_to :campaign
  belongs_to :account
  belongs_to :customer, optional: true

  STATUSES = %w[pending sent failed rejected].freeze
  validates :status, inclusion: { in: STATUSES }

  after_save :maybe_complete_campaign, if: :saved_change_to_status?
  after_save :broadcast_delivery_update, if: :saved_change_to_status?

  def log_activity!(activity_type, extra_props = {})
    return unless customer_id && campaign.environment_id

    LogCampaignActivityJob.perform_later(
      account_id: account_id,
      customer_id: customer_id,
      environment_id: campaign.environment_id,
      activity_type: activity_type,
      properties: {
        campaign_id: campaign_id,
        campaign_name: campaign.name,
        delivery_id: id
      }.merge(extra_props)
    )
  end

  private

  def broadcast_delivery_update
    return unless campaign.status.in?(%w[sending sent])

    ActionCable.server.broadcast(
      "campaign_#{campaign_id}",
      {
        type: "delivery_update",
        delivery: {
          id: id,
          status: status,
          email: email,
          error_message: error_message,
          sent_at: sent_at&.iso8601,
          open_count: open_count || 0,
          click_count: click_count || 0,
          customer: customer ? { id: customer.id, first_name: customer.first_name, last_name: customer.last_name } : nil
        },
        stats: campaign.stats,
        campaign_status: campaign.status
      }
    )
  end

  def maybe_complete_campaign
    return unless %w[sent failed rejected].include?(status)
    return unless campaign.status == 'sending'
    # Single cheap query instead of loading + checking
    return if CampaignDelivery.where(campaign_id: campaign_id, status: 'pending').exists?

    campaign.update_columns(status: 'sent', sent_at: Time.current)
  end
end
