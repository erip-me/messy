# Contact detail page: the customer plus recent activity, messages to them,
# active device tokens (masked) and page visits.
class CustomerDetailResource < CustomerResource
  attribute :activities do |customer|
    customer.customer_activities
            .includes(:environment)
            .order(created_at: :desc)
            .limit(50)
            .map do |a|
      {
        id: a.id,
        activity_type: a.activity_type,
        environment: a.environment&.name,
        properties: a.properties,
        created_at: a.created_at
      }
    end
  end

  attribute :messages do |customer|
    customer.account.messages
            .where("LOWER(\"to\") LIKE ?", "%#{customer.email.downcase}%")
            .includes(:environment)
            .order(created_at: :desc)
            .limit(50)
            .map do |m|
      {
        id: m.id,
        to: m.to,
        subject: m.subject,
        channel: m.type&.sub('Message', '')&.downcase,
        status: m.status,
        environment: m.environment&.name,
        created_at: m.created_at
      }
    end
  end

  attribute :device_tokens do |customer|
    customer.device_tokens.active.map do |dt|
      {
        id: dt.id,
        platform: dt.platform,
        token: "#{dt.token[0..12]}...",
        created_at: dt.created_at
      }
    end
  end

  attribute :page_visits do |customer|
    PageVisit.where(customer_id: customer.id)
             .recent.limit(50)
             .map { |v| { id: v.id, url: v.url, title: v.title, visited_at: v.visited_at } }
  end
end
