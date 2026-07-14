# A message plus its delivery attempts (used for child messages inside the
# message detail payload).
class MessageWithDeliveriesResource < MessageResource
  attribute :deliveries do |m|
    DeliveryResource.new(m.deliveries).to_h
  end
end
