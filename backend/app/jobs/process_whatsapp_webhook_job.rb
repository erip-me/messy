class ProcessWhatsappWebhookJob < ApplicationJob
  include DeliveryStatusUpdating

  queue_as :default

  STATUS_RANK = { "accepted" => 0, "sent" => 1, "delivered" => 2, "read" => 3, "failed" => 99 }.freeze

  def perform(payload)
    return unless payload["object"] == "whatsapp_business_account"

    payload["entry"]&.each do |entry|
      entry["changes"]&.each do |change|
        next unless change["field"] == "messages"

        statuses = change.dig("value", "statuses") || []
        statuses.each { |status_data| process_status(status_data) }
      end
    end
  end

  private

  def process_status(status_data)
    provider_id = status_data["id"]
    new_status = status_data["status"]
    errors = status_data["errors"]

    delivery = Delivery.find_by(provider_message_id: provider_id)
    return unless delivery

    # Only progress forward — never regress status
    return if status_superseded?(delivery.status, new_status)

    attrs = { status: new_status }
    if errors.present?
      attrs[:error] = errors.map { |e| "#{e["code"]}: #{e["title"]}" }.join("; ")
    end

    delivery.update!(attrs)
    update_message_status(delivery.message, new_status)
  end

  # update_message_status / status_superseded? provided by DeliveryStatusUpdating.
end
