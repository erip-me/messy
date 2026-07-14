class Campaign < ApplicationRecord
  belongs_to :account
  belongs_to :segment, optional: true
  belongs_to :template, optional: true
  belongs_to :environment, optional: true
  belongs_to :sending_identity, optional: true
  has_many :campaign_deliveries, dependent: :destroy

  STATUSES = %w[draft sending sent failed].freeze
  CHANNELS = %w[email sms whatsapp push].freeze

  CHANNEL_KIND_MAP = {
    'email' => :email,
    'sms' => :sms,
    'whatsapp' => :whatsapp,
    'push' => :mobile_push
  }.freeze

  validates :name, presence: true
  validates :status, inclusion: { in: STATUSES }
  validates :channel, inclusion: { in: CHANNELS }
  validates :subject, presence: true, if: -> { channel == 'email' }
  validate :segment_belongs_to_account, if: :segment_id
  validate :template_belongs_to_account, if: :template_id
  validate :environment_belongs_to_account, if: :environment_id
  validate :sending_identity_belongs_to_account, if: :sending_identity_id

  def channel_integration
    return nil unless environment

    kind = CHANNEL_KIND_MAP[channel]
    environment.resolve_integration(kind, purpose: :campaign)
  end

  # Computes stats for many campaigns in a fixed number of queries (3) instead of
  # ~2 per campaign. Returns { campaign_id => stats_hash }.
  def self.stats_for(campaigns)
    campaigns = campaigns.to_a
    ids = campaigns.map(&:id)
    return {} if ids.empty?

    status_counts = CampaignDelivery.where(campaign_id: ids).group(:campaign_id, :status).count
    opened_counts = CampaignDelivery.where(campaign_id: ids).where('open_count > 0').group(:campaign_id).count
    unsub_counts  = CustomerActivity
                      .where(account_id: campaigns.map(&:account_id).uniq, activity_type: 'campaign_unsubscribed')
                      .where("properties ->> 'campaign_id' IN (?)", ids.map(&:to_s))
                      .group(Arel.sql("properties ->> 'campaign_id'"))
                      .distinct.count(:customer_id)

    by_campaign = Hash.new { |h, k| h[k] = Hash.new(0) }
    status_counts.each { |(cid, status), n| by_campaign[cid][status] = n }

    campaigns.each_with_object({}) do |campaign, result|
      statuses = by_campaign[campaign.id]
      total    = statuses.values.sum
      sent     = statuses['sent'] || 0
      opened   = opened_counts[campaign.id] || 0
      result[campaign.id] = {
        total:        total,
        sent:         sent,
        failed:       statuses['failed'] || 0,
        pending:      statuses['pending'] || 0,
        rejected:     statuses['rejected'] || 0,
        open_rate:    sent > 0 ? (opened.to_f / sent * 100).round(1) : 0,
        unsubscribed: unsub_counts[campaign.id.to_s] || 0
      }
    end
  end

  def stats
    counts = campaign_deliveries.group(:status).count
    total = counts.values.sum
    return { total: 0, sent: 0, failed: 0, pending: 0, rejected: 0, open_rate: 0, unsubscribed: 0 } if total.zero?

    sent_count = counts['sent'] || 0
    opened_count = campaign_deliveries.where('open_count > 0').count

    {
      total:        total,
      sent:         sent_count,
      failed:       counts['failed'] || 0,
      pending:      counts['pending'] || 0,
      rejected:     counts['rejected'] || 0,
      open_rate:    sent_count > 0 ? (opened_count.to_f / sent_count * 100).round(1) : 0,
      unsubscribed: unsubscribed_count
    }
  end

  def unsubscribe_activities
    CustomerActivity
      .where(account_id: account_id, activity_type: 'campaign_unsubscribed')
      .where("properties ->> 'campaign_id' = ?", id.to_s)
  end

  def unsubscribed_count
    # Count distinct people, not raw activity rows — scanners/prefetchers and
    # repeat clicks can log several unsubscribe events for one person, which
    # would over-count otherwise.
    unsubscribe_activities.distinct.count(:customer_id)
  end

  def unsubscribed_delivery_ids
    unsubscribe_activities.pluck(Arel.sql("properties ->> 'delivery_id'")).compact
  end

  def all_delivered?
    campaign_deliveries.exists? && !campaign_deliveries.where(status: 'pending').exists?
  end

  private

  def segment_belongs_to_account
    errors.add(:segment, 'must belong to the same account') if segment && segment.account_id != account_id
  end

  def template_belongs_to_account
    errors.add(:template, 'must belong to the same account') if template && template.account_id != account_id
  end

  def environment_belongs_to_account
    errors.add(:environment, 'must belong to the same account') if environment && environment.account_id != account_id
  end

  def sending_identity_belongs_to_account
    errors.add(:sending_identity, 'must belong to the same account') if sending_identity && sending_identity.account_id != account_id
  end
end
