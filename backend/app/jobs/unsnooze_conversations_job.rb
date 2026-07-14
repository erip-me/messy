class UnsnoozeConversationsJob < ApplicationJob
  queue_as :default

  def perform
    Conversation.where(status: :snoozed)
                .where("snoozed_until <= ?", Time.current)
                .find_each do |conversation|
      conversation.update!(status: :open, snoozed_until: nil)

      ActionCable.server.broadcast(
        "operator_inbox_#{conversation.account_id}",
        { type: "conversation_update", conversation: conversation.as_inbox_json }
      )
    end
  end
end
