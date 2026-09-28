class ProcessWhatsappWebhookJob < ApplicationJob
  queue_as :default

  # Safe to rerun: WhatsappInbox skips anything already stored.
  retry_on StandardError, wait: :polynomially_longer, attempts: 5

  def perform(event_id)
    event = WhatsappWebhookEvent.find_by(id: event_id)
    return if event.nil? || event.processed_at
    return event.update!(processed_at: Time.current) unless event.payload["object"] == "whatsapp_business_account"

    Array(event.payload["entry"]).each do |entry|
      next unless entry.is_a?(Hash)
      integration = WhatsappIntegration.for_waba(entry["id"])
      unless integration
        Rails.logger.warn "[WhatsApp] webhook #{event.id}: no active integration for WABA #{entry["id"]}"
        next
      end
      inbox = WhatsappInbox.new(integration)
      Array(entry["changes"]).each { |change| inbox.process(change["field"], change["value"]) if change.is_a?(Hash) }
    end

    event.update!(processed_at: Time.current, error: nil)
  rescue => e
    event&.update_column(:error, "#{e.class}: #{e.message}".truncate(1000))
    raise
  end
end
