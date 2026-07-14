module EmailIngestion
  class Notifier
    EVENTS = %w[
      ticket_created
      ticket_assigned
      ticket_reply_from_operator
      ticket_closed
      ticket_reopened
    ].freeze

    attr_reader :conversation, :event, :trigger_message

    def initialize(conversation, event, trigger_message: nil)
      @conversation = conversation
      @event = event.to_s
      @trigger_message = trigger_message
      @email_thread = conversation.email_thread
      @mailbox = @email_thread&.mailbox
    end

    def notify!
      return unless @mailbox
      return unless EVENTS.include?(event)
      return unless @mailbox.notification_enabled?(event)

      # Rate-limit auto-replies to prevent loops with other auto-responders
      if event == "ticket_created"
        recent = EmailMessageDetail.joins(:conversation_message)
          .where(conversation_messages: { account_id: conversation.account_id, sender_type: "System" })
          .where(to_email: @email_thread.from_email)
          .where("email_message_details.created_at > ?", 5.minutes.ago)
          .exists?
        return if recent
      end

      mailer_params = { conversation: conversation, trigger_message: trigger_message }
      mail = TicketMailer.with(mailer_params).public_send(event)
      return unless mail # ticket_reopened returns nil if no assigned user

      mail.deliver_now
      record_outbound(mail)
    end

    private

    def record_outbound(mail)
      return if event == "ticket_reply_from_operator"

      to_email = Array(mail.to).first
      system_message = conversation.conversation_messages.create!(
        account: conversation.account,
        sender_type: "System",
        message_type: :system,
        content: "[#{event.humanize}] notification sent to #{to_email}",
        private: true
      )

      EmailMessageDetail.create!(
        conversation_message: system_message,
        message_id_header: mail.message_id,
        in_reply_to_header: mail["In-Reply-To"]&.to_s,
        from_email: Array(mail.from).first,
        to_email: to_email,
        cc_list: [],
        html_body: mail.html_part&.decoded,
        text_body: mail.text_part&.decoded
      )
    end
  end
end
