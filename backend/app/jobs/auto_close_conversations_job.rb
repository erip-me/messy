class AutoCloseConversationsJob < ApplicationJob
  queue_as :default

  def perform
    ChatWidgetSettings.where(enabled: true).find_each do |settings|
      hours = settings.auto_close_hours || 24
      cutoff = hours.hours.ago

      conversations = Conversation.where(account_id: settings.account_id)
                                  .where(status: [:open, :pending])
                                  .where("last_message_at < ?", cutoff)

      conversations.find_each do |conversation|
        conversation.update!(status: :closed, resolved_at: Time.current)
        conversation.conversation_messages.create!(
          account_id: conversation.account_id,
          sender_type: "System",
          message_type: :system,
          content: "This conversation was automatically closed due to inactivity."
        )

        ActionCable.server.broadcast(
          "conversation_#{conversation.id}",
          { type: "status_change", status: "closed" }
        )
      end
    end
  end
end
