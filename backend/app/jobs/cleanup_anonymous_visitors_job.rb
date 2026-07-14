class CleanupAnonymousVisitorsJob < ApplicationJob
  queue_as :default

  def perform
    Customer.where.not(anonymous_token: nil)
            .where(email: [nil, ""])
            .where("last_seen_at < ? OR last_seen_at IS NULL", 30.days.ago)
            .where.not(
              id: Conversation.select(:customer_id).where.not(customer_id: nil)
            )
            .delete_all
  end
end
