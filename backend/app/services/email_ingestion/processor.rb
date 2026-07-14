module EmailIngestion
  class Processor
    attr_reader :mailbox, :mail, :provider_uid, :account

    def initialize(mailbox, mail_message, provider_uid:)
      @mailbox = mailbox
      @mail = mail_message
      @provider_uid = provider_uid
      @account = mailbox.account
    end

    def process!
      return if duplicate?
      return if bounce_or_auto_reply?

      thread = find_existing_thread
      is_new_ticket = thread.nil?
      thread ||= create_new_thread

      conversation = thread.conversation
      message = create_conversation_message(conversation)
      create_email_detail(message)
      attach_files(message)
      update_cc_list(thread)

      # Reopen if conversation was closed/resolved and customer sent a new reply
      if !is_new_ticket && conversation.status.in?(%w[resolved closed])
        conversation.update!(status: :open)
        SendTicketNotificationJob.perform_later(
          conversation.id, "ticket_reopened", message.id
        )
      end

      # Auto-assign if unassigned and configured
      if conversation.assigned_user_id.nil? && mailbox.auto_assign
        ConversationAutoAssigner.assign(conversation)
      end

      # Auto-reply acknowledgement for new tickets
      if is_new_ticket && mailbox.auto_reply_enabled
        SendTicketNotificationJob.perform_later(
          conversation.id, "ticket_created", message.id
        )
      end

      # Alert operators about the new ticket
      NotifyOperatorsNewTicketJob.perform_later(conversation.id) if is_new_ticket

      message
    end

    private

    def duplicate?
      return false if provider_uid.blank?
      EmailMessageDetail.exists?(provider_uid: provider_uid)
    end

    def bounce_or_auto_reply?
      from = sender_email
      return true if from&.match?(/mailer-daemon|postmaster/i)

      # RFC 3834: auto-submitted header indicates automated responses
      auto_submitted = mail["Auto-Submitted"]&.to_s
      return true if auto_submitted.present? && auto_submitted != "no"

      return true if mail["X-Auto-Response-Suppress"].present?

      false
    end

    def find_existing_thread
      # Strategy 1: In-Reply-To header
      if mail.in_reply_to.present?
        reply_to = Array(mail.in_reply_to).first
        stripped = reply_to&.gsub(/\A<|>\z/, "")
        detail = account_scoped_details.find_by(message_id_header: reply_to) ||
                 account_scoped_details.find_by(message_id_header: "<#{stripped}>") ||
                 account_scoped_details.find_by(message_id_header: stripped)
        if detail
          return detail.conversation_message.conversation.email_thread
        end
      end

      # Strategy 2: Ticket number in subject
      ticket = parse_ticket_number(mail.subject)
      if ticket
        thread = EmailThread.find_by(account_id: account.id, ticket_number: ticket)
        return thread if thread
      end

      # Strategy 3: References header
      refs = Array(mail.references).compact
      if refs.any?
        detail = account_scoped_details.where(message_id_header: refs).first
        if detail
          return detail.conversation_message.conversation.email_thread
        end
      end

      nil
    end

    # Message-ID/References headers are attacker-controlled, so thread lookups must be
    # scoped to this account — otherwise a forged In-Reply-To/References could graft a
    # message into another tenant's conversation (cross-account data leak).
    def account_scoped_details
      EmailMessageDetail
        .joins(conversation_message: :conversation)
        .where(conversations: { account_id: account.id })
    end

    def create_new_thread
      ticket_number = mailbox.next_ticket_number!
      customer = find_or_create_customer

      conversation = Conversation.create!(
        account: account,
        environment: mailbox.environment,
        customer: customer,
        visitor_token: "email_#{SecureRandom.hex(16)}",
        visitor_name: sender_name,
        visitor_email: sender_email,
        status: :open,
        source: :email,
        subject: clean_subject,
        ticket_number: ticket_number
      )

      EmailThread.create!(
        account: account,
        mailbox: mailbox,
        conversation: conversation,
        ticket_number: ticket_number,
        from_email: sender_email,
        from_name: sender_name,
        subject: clean_subject,
        in_reply_to: mail.in_reply_to,
        references_header: Array(mail.references).join(" "),
        cc_list: extract_cc_list
      )
    end

    def parse_ticket_number(subject)
      return nil unless subject
      # Match patterns: [SUP-1234], [#1234], SUP-1234, #1234
      match = subject.match(/\[?([A-Z]+-\d{4,}|#\d{4,})\]?/)
      match ? match[1] : nil
    end

    def clean_subject
      mail.subject&.gsub(/\A\s*(Re|Fwd?|FW)\s*:\s*/i, "")&.strip
    end

    def sender_email
      mail.from&.first&.downcase
    end

    def sender_name
      addr = mail[:from]&.addrs&.first
      addr&.display_name || sender_email
    end

    def extract_cc_list
      (mail.cc || []).map(&:downcase)
    end

    def find_or_create_customer
      Customer.find_or_create_by!(account: account, email: sender_email) do |c|
        parts = sender_name&.split(" ", 2)
        c.first_name = parts&.first
        c.last_name = parts&.last if parts&.length.to_i > 1
      end
    end

    def create_conversation_message(conversation)
      text_content = extract_text_body

      conversation.conversation_messages.create!(
        account: account,
        sender_type: "Customer",
        sender_id: conversation.customer_id,
        message_type: :text,
        content: text_content,
        private: false,
        metadata: { "email" => true }
      )
    end

    def create_email_detail(message)
      EmailMessageDetail.create!(
        conversation_message: message,
        message_id_header: mail.message_id,
        in_reply_to_header: Array(mail.in_reply_to).first,
        from_email: sender_email,
        from_name: sender_name,
        to_email: mailbox.email_address,
        cc_list: extract_cc_list,
        html_body: sanitize_html(extract_html_body),
        text_body: extract_text_body,
        raw_headers: extract_selected_headers,
        provider_uid: provider_uid
      )
    end

    def sanitize_html(html)
      return nil if html.blank?
      Loofah.fragment(html).scrub!(:prune).to_s
    end

    def extract_text_body
      @extracted_text_body ||= compute_text_body
    end

    def compute_text_body
      if mail.multipart?
        text_part = mail.text_part
        if text_part
          strip_signature(text_part.decoded)
        else
          Html2Text.convert(extract_html_body || "")
        end
      else
        if mail.content_type&.include?("text/html")
          Html2Text.convert(mail.decoded)
        else
          strip_signature(mail.decoded)
        end
      end
    rescue => e
      Rails.logger.error "[Processor] Failed to extract text body: #{e.message}"
      mail.subject || "(no content)"
    end

    def extract_html_body
      @extracted_html_body ||= compute_html_body
    end

    def compute_html_body
      if mail.multipart?
        mail.html_part&.decoded
      elsif mail.content_type&.include?("text/html")
        mail.decoded
      end
    rescue => e
      Rails.logger.error "[Processor] Failed to extract HTML body: #{e.message}"
      nil
    end

    def strip_signature(text)
      return text if text.blank?
      text.split(/^-- ?\n|^---\n|^Sent from my /m).first&.strip
    end

    def attach_files(message)
      mail.attachments.each do |att|
        # Skip inline text parts without filenames
        next if att.content_type&.start_with?("text/") && att.filename.blank?

        decoded = att.body.decoded
        if decoded.bytesize > 25.megabytes
          # Add system note about skipped attachment
          message.conversation.conversation_messages.create!(
            account: account,
            sender_type: "System",
            message_type: :system,
            content: "Attachment \"#{att.filename}\" was too large to include (#{(decoded.bytesize / 1.megabyte).round(1)} MB limit: 25 MB).",
            private: true
          )
          next
        end

        message.attachments.attach(
          io: StringIO.new(decoded),
          filename: att.filename || "attachment",
          content_type: att.content_type&.split(";")&.first || "application/octet-stream"
        )
      end
    end

    def update_cc_list(thread)
      new_cc = extract_cc_list
      return if new_cc.empty?

      existing = thread.cc_list || []
      merged = (existing + new_cc).uniq
      thread.update!(cc_list: merged) if merged != existing
    end

    def extract_selected_headers
      %w[Date From To Cc Subject Message-ID In-Reply-To References].each_with_object({}) do |name, h|
        val = mail[name]
        h[name] = val.to_s if val.present?
      end
    end
  end
end
