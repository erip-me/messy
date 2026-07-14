module EmailIngestion
  class ReplySender
    attr_reader :message, :conversation, :email_thread, :mailbox

    def initialize(conversation_message)
      @message = conversation_message
      @conversation = conversation_message.conversation
      @email_thread = @conversation.email_thread
      @mailbox = @email_thread.mailbox
    end

    def send!
      integration = mailbox.environment.resolve_integration(:email)
      raise "No email integration configured for environment #{mailbox.environment.name}" unless integration

      mail = build_mail(integration)
      integration.send_raw_mail!(mail)
      Rails.logger.info "[ReplySender] Sent reply for ticket #{email_thread.ticket_number}"
      create_email_detail(mail)
    end

    private

    def build_mail(integration)
      from = mailbox.from_address(integration)
      ticket = email_thread.ticket_number
      subject = email_thread.subject
      subject_with_ticket = subject&.include?(ticket) ? "Re: #{subject}" : "Re: [#{ticket}] #{subject}"

      mail = Mail.new do |m|
        m.from    from
        m.to      email_thread.from_email
        m.cc      email_thread.cc_list if email_thread.cc_list.present?
        m.subject subject_with_ticket
      end

      email_thread.apply_threading_headers!(mail)

      content = message.content || ""
      escaped = ERB::Util.html_escape(content).gsub("\n", "<br>")

      mail.text_part = Mail::Part.new { body content }
      mail.html_part = Mail::Part.new do
        content_type "text/html; charset=UTF-8"
        body "<div>#{escaped}</div>"
      end

      if message.attachments.attached?
        message.attachments.each do |att|
          mail.add_file(filename: att.filename.to_s, content: att.download, mime_type: att.content_type)
        end
      end

      mail
    end

    def create_email_detail(mail)
      EmailMessageDetail.create!(
        conversation_message: message,
        message_id_header: mail.message_id,
        in_reply_to_header: mail.in_reply_to,
        from_email: mailbox.email_address,
        to_email: email_thread.from_email,
        cc_list: email_thread.cc_list || [],
        html_body: message.content,
        text_body: message.content
      )
    end
  end
end
