class OfflineMessageJob < ApplicationJob
  queue_as :default

  def perform(account_id, visitor_name, visitor_email, message_content, metadata = {})
    account = Account.find(account_id)
    environment = account.environments.where(is_deleted: false).first
    return unless environment

    conversation = Conversation.create!(
      account: account,
      environment: environment,
      visitor_token: metadata["visitor_token"] || SecureRandom.uuid,
      visitor_name: visitor_name,
      visitor_email: visitor_email,
      status: :pending,
      source: :widget,
      ticket_number: account.next_ticket_number!,
      visitor_ip: metadata["ip"],
      visitor_user_agent: metadata["user_agent"]
    )

    conversation.conversation_messages.create!(
      account: account,
      sender_type: "Customer",
      message_type: :text,
      content: message_content
    )

    NotifyOperatorsNewTicketJob.perform_later(conversation.id)
  end
end
