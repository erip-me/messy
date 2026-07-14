class CustomerActivity < ApplicationRecord
  belongs_to :account
  belongs_to :customer
  belongs_to :environment, optional: true

  after_create_commit :broadcast_create

  private

  def broadcast_create
    ActionCable.server.broadcast "messages_channel_#{account_id}", {
      type: "customer_activity",
      activity: {
        id: id,
        activity_type: activity_type,
        customer: {
          id: customer.id,
          email: customer.email,
          first_name: customer.first_name,
          last_name: customer.last_name
        },
        environment: environment&.name,
        properties: properties,
        created_at: created_at
      },
      action: "create"
    }
  end
end
