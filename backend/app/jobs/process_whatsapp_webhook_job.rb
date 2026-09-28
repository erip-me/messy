class ProcessWhatsappWebhookJob < ApplicationJob
  queue_as :default

  # Safe to rerun: WhatsappInbox skips anything already stored.
  retry_on StandardError, wait: :polynomially_longer, attempts: 5

  def perform(event_id)
    event = WhatsappWebhookEvent.find_by(id: event_id)
    return if event.nil? || event.processed_at
    return event.update!(processed_at: Time.current) unless event.payload["object"] == "whatsapp_business_account"

    allowed = WhatsappIntegration.where(id: event.authorized_integration_ids, active: true).to_a
    Array(event.payload["entry"]).each do |entry|
      next unless entry.is_a?(Hash)
      for_waba = allowed.select { |i| i.business_account_id.to_s == entry["id"].to_s }
      if for_waba.empty?
        Rails.logger.warn "[WhatsApp] webhook #{event.id}: no authorized integration for WABA #{entry["id"]}"
        next
      end

      Array(entry["changes"]).each do |change|
        next unless change.is_a?(Hash)
        # A WABA can hold several numbers; changes carrying a phone_number_id go
        # only to that number's integration (others in the WABA aren't ours).
        phone_id = change.dig("value", "metadata", "phone_number_id") if change["value"].is_a?(Hash)
        targets = phone_id ? for_waba.select { |i| i.phone_id.to_s == phone_id.to_s } : for_waba
        targets.each { |i| WhatsappInbox.new(i).process(change["field"], change["value"]) }
      end
    end

    event.update!(processed_at: Time.current, error: nil)
  rescue => e
    event&.update_column(:error, "#{e.class}: #{e.message}".truncate(1000))
    raise
  end
end
