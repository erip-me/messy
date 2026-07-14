class NotifyOperatorsNewTicketJob < ApplicationJob
  queue_as :default

  def perform(conversation_id)
    conversation = Conversation.find(conversation_id)
    account = conversation.account

    recipients = account.users.joins(:operator_profile).where(operator_profiles: { auto_assign: true })
    recipients = account.users if recipients.empty?

    recipients.find_each do |user|
      TicketMailer.with(conversation: conversation, operator: user).new_ticket_alert.deliver_later
    end
  end
end
