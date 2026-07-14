class SendTicketNotificationJob < ApplicationJob
  queue_as :email_ingestion

  retry_on StandardError, wait: :polynomially_longer, attempts: 3

  def perform(conversation_id, event, trigger_message_id = nil)
    conversation = Conversation.find(conversation_id)
    trigger_message = trigger_message_id ? ConversationMessage.find_by(id: trigger_message_id) : nil

    EmailIngestion::Notifier.new(
      conversation,
      event,
      trigger_message: trigger_message
    ).notify!
  end
end
