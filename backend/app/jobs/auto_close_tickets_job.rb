class AutoCloseTicketsJob < ApplicationJob
  queue_as :email_ingestion

  def perform
    Mailbox.active_mailboxes.where.not(auto_close_days: nil).find_each do |mailbox|
      close_stale_tickets(mailbox)
    end
  end

  private

  def close_stale_tickets(mailbox)
    cutoff = mailbox.auto_close_days.days.ago

    stale_conversations = Conversation
      .joins(:email_thread)
      .where(email_threads: { mailbox_id: mailbox.id })
      .where(status: [:open, :pending])
      .where("conversations.last_message_at < ? OR (conversations.last_message_at IS NULL AND conversations.created_at < ?)", cutoff, cutoff)

    stale_conversations.find_each do |conversation|
      conversation.update!(status: :closed, resolved_at: Time.current)

      conversation.conversation_messages.create!(
        account: conversation.account,
        sender_type: "System",
        message_type: :system,
        content: "This ticket was automatically closed after #{mailbox.auto_close_days} days of inactivity.",
        private: false
      )

      if mailbox.notification_enabled?("ticket_closed")
        SendTicketNotificationJob.perform_later(conversation.id, "ticket_closed")
      end

      Rails.logger.info "[AutoCloseTicketsJob] Closed ticket #{conversation.ticket_number} (#{mailbox.auto_close_days} days inactive)"
    end
  end
end
