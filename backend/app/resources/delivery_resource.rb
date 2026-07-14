class DeliveryResource
  include Alba::Resource

  attributes :id, :account_id, :message_id, :integration_id, :recipient,
             :status, :error, :provider_message_id, :started_at, :completed_at,
             :created_at, :updated_at
end
