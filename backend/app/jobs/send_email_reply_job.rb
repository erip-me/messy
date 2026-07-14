class SendEmailReplyJob < ApplicationJob
  queue_as :email_ingestion

  retry_on StandardError, wait: :polynomially_longer, attempts: 3

  def perform(conversation_message_id)
    message = ConversationMessage.find(conversation_message_id)
    EmailIngestion::ReplySender.new(message).send!
  end
end
