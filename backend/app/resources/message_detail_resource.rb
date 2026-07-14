# The message detail payload: full message, its deliveries, and per-recipient
# child messages with theirs. Request-specific extras (attachments URLs,
# customer lookup, template/drip info) are merged in by the controller.
class MessageDetailResource < MessageWithDeliveriesResource
  attribute :child_messages do |m|
    MessageWithDeliveriesResource.new(m.child_messages).to_h
  end

  attribute :channel do |m|
    m.type&.sub('Message', '')&.underscore
  end

  attribute :environment do |m|
    m.environment&.name
  end
end
