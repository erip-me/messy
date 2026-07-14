# Campaign with its lightweight association summaries and delivery stats.
# Pass params[:stats_by_campaign] (from Campaign.stats_for) on index to avoid
# per-campaign stats queries.
class CampaignResource
  include Alba::Resource

  attributes :id, :account_id, :environment_id, :segment_id, :template_id,
             :sending_identity_id, :name, :channel, :subject, :content,
             :from_email, :status, :recipient_count, :sent_at,
             :created_at, :updated_at

  # Nil associations are omitted (not null) to match as_json's include behavior.
  attribute :segment, if: proc { |c| c.segment } do |c|
    { id: c.segment.id, name: c.segment.name }
  end

  attribute :template, if: proc { |c| c.template } do |c|
    { id: c.template.id, name: c.template.name, channel: c.template.channel }
  end

  attribute :sending_identity, if: proc { |c| c.sending_identity } do |c|
    { id: c.sending_identity.id, from_name: c.sending_identity.from_name, from_email: c.sending_identity.from_email }
  end

  attribute :stats do |c|
    (params[:stats_by_campaign] && params[:stats_by_campaign][c.id]) || c.stats
  end
end
