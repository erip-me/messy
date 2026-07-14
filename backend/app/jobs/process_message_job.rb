require 'mail'

class ProcessMessageJob < ApplicationJob
  queue_as :default

  def perform(message)
    Rails.logger.info "Processing message #{message.id}"

    recipient_results = recipient_list(message)

    if all_recipients_passed?(recipient_results)
      Rails.logger.info "All recipients passed, delivering message #{message.id} to all recipients"
      DeliverMessageJob.perform_later(message)
    else
      has_any_passed = false

      recipient_results.each do |recipient, result|
        case result
        when :passed
          Rails.logger.info "Rule match for #{recipient[:rcpt]}, creating child message for this recipient"
          child = create_child_message(message, recipient)
          DeliverMessageJob.perform_later(child)
          has_any_passed = true
        when :suppressed
          Rails.logger.info "Suppressed #{recipient[:rcpt]} — customer unsubscribed from #{channel_for(message)}"
          create_child_message(message, recipient, status: :suppressed)
        when :rejected
          Rails.logger.info "Rejected #{recipient[:rcpt]} by rules, creating rejected child message"
          create_child_message(message, recipient, status: :rejected)
        end
      end

      unless has_any_passed
        final_status = recipient_results.values.all? { |v| v == :suppressed } ? :suppressed : :rejected
        message.update!(status: final_status)
      end
    end
  end

  protected
    def parse_email_addresses(email_string)
      addresses = Mail::AddressList.new(email_string)
      addresses.addresses.map do |address|
        { name: address.display_name, rcpt: address.address, raw: address.to_s }
      end
    end

    def recipient_list(message)
      channel = channel_for(message)
      recipients = parse_email_addresses(message.to) + parse_email_addresses(message.cc) + parse_email_addresses(message.bcc)
      recipients.each_with_object({}) do |recipient, result|
        if channel && customer_suppressed?(message.account, recipient[:rcpt], channel)
          result[recipient] = :suppressed
        elsif message.environment.check_rules?(message, recipient[:rcpt]) == :passed
          result[recipient] = :passed
        else
          result[recipient] = :rejected
        end
      end
    end

    def all_recipients_passed?(recipient_results)
      recipient_results.values.all? { |v| v == :passed }
    end

    def customer_suppressed?(account, email, channel)
      addr = email.to_s.downcase
      customer = account.customers.find_by(email: addr)
      customer&.unsubscribed_from?(channel) || false
    end

    def channel_for(message)
      case message
      when EmailMessage then "email"
      when SmsMessage then "sms"
      when WhatsappMessage then "whatsapp"
      when MobilePushMessage, WebPushMessage then "push"
      end
    end

    def create_child_message(parent, recipient, status: :pending)
      child = parent.child_messages.create!(
        account: parent.account,
        environment: parent.environment,
        template: parent.template,
        type: parent.type,
        trigger: parent.trigger,
        to: recipient[:raw],
        subject: parent.subject,
        body: parent.body,
        tags: parent.tags,
        scope: parent.scope,
        status: status
      )

      parent.attachments.each { |attachment| child.attachments.attach(attachment.blob) }

      child
    end
end
