# A row in the transactional messages list. Only the columns the list view
# renders; the body can be large HTML (20 rows/page), so it's truncated — the
# list only ever shows the first ~80 chars as a subject fallback.
class MessageListResource
  include Alba::Resource

  attributes :id, :to, :subject, :status, :scope, :environment_id,
             :created_at, :sent_at, :parent_message_id, :tracking_token,
             :drip_campaign_id, :drip_step_id, :open_count, :click_count

  attribute :type, &:type

  attribute :body do |m|
    m.body&.truncate(120)
  end

  attribute :channel do |m|
    m.type&.sub('Message', '')&.underscore
  end

  attribute :environment do |m|
    m.environment&.name
  end
end
