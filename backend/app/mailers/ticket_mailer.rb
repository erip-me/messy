class TicketMailer < ApplicationMailer
  def ticket_created
    setup_common
    @auto_reply_html = render_auto_reply_body

    build_threaded_mail(
      to: @email_thread.from_email,
      subject: "Re: [#{@ticket_number}] #{@subject}"
    )
  end

  def ticket_assigned
    setup_common
    @operator_name = @conversation.assigned_user&.name || "an operator"

    build_threaded_mail(
      to: @email_thread.requester_and_cc,
      subject: "Re: [#{@ticket_number}] #{@subject} - Ticket Assigned"
    )
  end

  def ticket_reply_from_operator
    setup_common
    @reply_content = params[:trigger_message]&.content || ""
    attach_trigger_message_files

    build_threaded_mail(
      to: @email_thread.requester_and_cc,
      subject: "Re: [#{@ticket_number}] #{@subject}"
    )
  end

  def ticket_closed
    setup_common

    build_threaded_mail(
      to: @email_thread.requester_and_cc,
      subject: "Re: [#{@ticket_number}] #{@subject} - Ticket Resolved"
    )
  end

  def ticket_reopened
    setup_common
    @requester = @email_thread.from_name || @email_thread.from_email
    @preview = params[:trigger_message]&.content&.truncate(500)

    user = @conversation.assigned_user
    return unless user

    build_threaded_mail(
      to: user.email,
      subject: "[#{@ticket_number}] #{@subject} - Ticket Reopened"
    )
  end

  def new_ticket_alert
    @conversation = params[:conversation]
    @operator = params[:operator]
    @frontend_url = ENV.fetch("FRONTEND_URL", "http://localhost:5174")
    @inbox_link = "#{@frontend_url}/inbox/#{@conversation.id}"
    @ticket_number = @conversation.ticket_number
    @subject = @conversation.subject || "New conversation"
    @requester_name = @conversation.visitor_name || @conversation.visitor_email
    @requester_email = @conversation.visitor_email
    @preview = @conversation.conversation_messages.order(:created_at).first&.content&.truncate(500)
    @source_label = @conversation.source_email? ? "Email" : "Chat"

    mail(
      to: @operator.email,
      subject: "[#{@ticket_number}] #{@subject} - New Ticket"
    )
  end

  private

  def setup_common
    @conversation = params[:conversation]
    @email_thread = @conversation.email_thread
    @mailbox = @email_thread.mailbox
    @ticket_number = @email_thread.ticket_number
    @subject = @email_thread.subject
    @frontend_url = ENV.fetch("FRONTEND_URL", "http://localhost:5174")
    @inbox_link = "#{@frontend_url}/inbox/#{@conversation.id}"
  end

  def build_threaded_mail(to:, subject:)
    from = @mailbox.from_address(
      @mailbox.environment.resolve_integration(:email)
    )

    msg = mail(from: from, to: to, subject: subject)
    @email_thread.apply_threading_headers!(msg)
    msg
  end

  def attach_trigger_message_files
    msg = params[:trigger_message]
    return unless msg&.attachments&.attached?

    msg.attachments.each do |att|
      attachments[att.filename.to_s] = {
        mime_type: att.content_type,
        content: att.download
      }
    end
  end

  def render_auto_reply_body
    template_text = @mailbox.auto_reply_template
    if template_text.present?
      Liquid::Template.parse(template_text).render(
        "ticket_number" => @ticket_number,
        "subject" => @subject,
        "sender_name" => @email_thread.from_name || @email_thread.from_email
      ).html_safe
    end
  end
end
