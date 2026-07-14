# Customer context panel next to a conversation, with their recent page visits.
class InboxCustomerResource
  include Alba::Resource

  attributes :id, :email, :first_name, :last_name, :custom_attributes,
             :online, :last_seen_at, :country, :city, :browser, :os

  attribute :recent_pages do |customer|
    PageVisit.where(account_id: customer.account_id, customer_id: customer.id)
             .recent.limit(5)
             .map { |v| { url: v.url, title: v.title, visited_at: v.visited_at } }
  end
end
