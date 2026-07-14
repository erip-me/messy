require 'mail'

class DeliverMessageJob < ApplicationJob
  queue_as :default

  # No tokens = permanent failure, skip retries entirely.
  discard_on NoTokensError do |job, error|
    message = job.arguments.first
    if message.is_a?(Message)
      message.update(status: :failed)
      Rails.logger.error "[DeliverMessageJob] #{error.message} — message #{message.id} failed (no tokens)"
      DeliverMessageJob.resolve_parent_status(message)
    end
  end

  # Retry up to 5 times with exponential backoff: ~15s, ~30s, ~75s, ~4m, ~10m
  # On final failure, mark the message as failed.
  retry_on StandardError, wait: :polynomially_longer, attempts: 5 do |job, error|
    message = job.arguments.first
    if message.is_a?(Message)
      message.update(status: :failed)
      Rails.logger.error "[DeliverMessageJob] Retries exhausted for message #{message.id}: #{error.message}"
      DeliverMessageJob.resolve_parent_status(message)
    end
  end

  def perform(message, force: false)
    unless force
      # Skip delivery if the message has been expired (stale pending > 4h)
      if message.expired?
        Rails.logger.info "[DeliverMessageJob] Skipping expired message #{message.id}"
        return
      end

      # Expire on-the-fly if still pending but too old
      if message.pending? && message.created_at < 4.hours.ago
        message.update!(status: :expired)
        Rails.logger.info "[DeliverMessageJob] Expired stale message #{message.id} at delivery time"
        return
      end
    end

    # Skip if already failed (e.g. parent marked failed)
    if message.failed?
      Rails.logger.info "[DeliverMessageJob] Skipping already-failed message #{message.id}"
      return
    end

    # Skip if rejected by rules
    if message.rejected?
      Rails.logger.info "[DeliverMessageJob] Skipping rejected message #{message.id}"
      return
    end

    # Mobile push may need multiple integrations (FCM + APNs)
    if message.is_a?(MobilePushMessage)
      deliver_push(message)
    else
      deliver_single(message)
    end

    self.class.resolve_parent_status(message)
  end

  def deliver_single(message)
    integration = build_integration(message)
    recipient = message.parent_message_id? ? message.to : nil

    # Fail immediately if no integration is configured — retrying won't help.
    unless integration
      error_msg = "No #{message.class.name.underscore.humanize.downcase} integration configured"
      Rails.logger.error "[DeliverMessageJob] Message #{message.id}: #{error_msg}"
      message.update!(status: :failed)
      return
    end

    delivery = Delivery.create!(
      account: message.account,
      message: message,
      integration: integration,
      recipient: recipient || message.to,
      started_at: Time.now
    )

    begin
      from_line = integration.kind == "email" ? SendingIdentity.from_line(message.sending_identity, message.account) : nil
      result = if from_line
        integration.deliver!(message, recipient, from: from_line)
      else
        integration.deliver!(message, recipient)
      end

      now = Time.current
      message.update! status: :sent, sent_at: now

      begin
        touch_customer_engaged(message, at: now)
      rescue => e
        Rails.logger.warn "[DeliverMessageJob] Failed to touch last_engaged_at for message #{message.id}: #{e.message}"
      end

      delivery_attrs = { completed_at: Time.now }
      if result.is_a?(Hash) && result.dig("messages", 0, "id")
        delivery_attrs[:provider_message_id] = result.dig("messages", 0, "id")
        delivery_attrs[:status] = "accepted"
      end
      delivery.update!(delivery_attrs)
    rescue => e
      Rails.logger.error "[DeliverMessageJob] Message #{message.id} failed: #{e.message}"
      delivery.update! completed_at: Time.now, error: e.message
      raise
    end
  end

  def deliver_push(message)
    push_integrations = message.environment.resolve_push_integrations
    recipient = message.parent_message_id? ? message.to : nil

    if push_integrations.empty?
      Rails.logger.error "[DeliverMessageJob] Message #{message.id}: No push integration configured"
      message.update!(status: :failed)
      return
    end

    errors = []
    no_tokens_count = 0

    push_integrations.each do |_kind, integration|
      delivery = Delivery.create!(
        account: message.account,
        message: message,
        integration: integration,
        recipient: recipient || message.to,
        started_at: Time.now
      )

      begin
        integration.deliver!(message, recipient)
        delivery.update!(completed_at: Time.now)
      rescue NoTokensError => e
        Rails.logger.warn "[DeliverMessageJob] Push via #{integration.type} for message #{message.id}: #{e.message}"
        delivery.update!(completed_at: Time.now, error: e.message)
        errors << e.message
        no_tokens_count += 1
      rescue => e
        Rails.logger.warn "[DeliverMessageJob] Push via #{integration.type} for message #{message.id}: #{e.message}"
        delivery.update!(completed_at: Time.now, error: e.message)
        errors << e.message
      end
    end

    # If all integrations failed, raise so the job retries (or discards if no tokens)
    if errors.length == push_integrations.length
      if no_tokens_count == push_integrations.length
        raise NoTokensError, "No push tokens found for any platform"
      end
      raise "All push integrations failed: #{errors.join(', ')}"
    end

    now = Time.current
    message.update!(status: :sent, sent_at: now)

    begin
      touch_customer_engaged(message, at: now)
    rescue => e
      Rails.logger.warn "[DeliverMessageJob] Failed to touch last_engaged_at for message #{message.id}: #{e.message}"
    end
  end

  def build_integration(message)
    kind = case message
           when EmailMessage then :email
           when SmsMessage then :sms
           when WhatsappMessage then :whatsapp
           when MobilePushMessage then :mobile_push
           when WebPushMessage then :web_push
           end

    message.environment.resolve_integration(kind, purpose: :notification)
  end

  def touch_customer_engaged(message, at:)
    return unless message.to.present?

    email = Mail::Address.new(message.to).address&.downcase
    return unless email

    customer = message.account.customers.find_by(email: email)
    customer&.touch_last_engaged(at: at)
  end

  def self.resolve_parent_status(message)
    parent = message.parent_message
    return unless parent

    children = parent.child_messages
    return if children.empty?
    return if children.where(status: :pending).exists?

    statuses = children.pluck(:status).uniq

    new_status = if statuses == ["rejected"]
                   :rejected
                 elsif statuses == ["suppressed"]
                   :suppressed
                 elsif statuses.all? { |s| s.in?(%w[rejected suppressed]) }
                   :rejected
                 elsif statuses.all? { |s| s == "delivered" }
                   :delivered
                 elsif statuses.include?("delivered") || statuses.include?("sent")
                   :sent
                 elsif statuses.include?("failed")
                   :failed
                 elsif statuses == ["expired"]
                   :expired
                 else
                   :failed
                 end

    attrs = { status: new_status }
    attrs[:sent_at] = Time.current if new_status == :sent
    parent.update!(attrs)
  end
end
