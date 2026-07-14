class CampaignDeliveryResource
  include Alba::Resource

  attributes :id, :account_id, :campaign_id, :customer_id, :channel, :email,
             :status, :error_message, :sent_at, :opened_at, :open_count,
             :click_count, :tracking_token, :created_at, :updated_at

  attribute :customer, if: proc { |d| d.customer } do |d|
    { id: d.customer.id, first_name: d.customer.first_name, last_name: d.customer.last_name }
  end
end
