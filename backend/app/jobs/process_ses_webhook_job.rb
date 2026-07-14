class ProcessSesWebhookJob < ApplicationJob
  include DeliveryStatusUpdating

  queue_as :default

  STATUS_RANK = { "accepted" => 0, "sent" => 1, "delivered" => 2, "failed" => 99 }.freeze

  def perform(event)
    event_type = event["eventType"] || event["notificationType"]
    mail_data = event["mail"]
    return unless mail_data

    provider_id = mail_data["messageId"]
    delivery = Delivery.find_by(provider_message_id: provider_id)
    return unless delivery

    case event_type
    when "Delivery"
      update_delivery(delivery, "delivered")
    when "Bounce"
      bounce = event["bounce"] || {}
      error = "Bounce: #{bounce["bounceType"]} / #{bounce["bounceSubType"]}"
      update_delivery(delivery, "failed", error: error)
      unsubscribe_recipient(delivery, reason: "bounce") if bounce["bounceType"] == "Permanent"
    when "Complaint"
      complaint = event["complaint"] || {}
      error = "Complaint: #{complaint["complaintFeedbackType"] || "abuse"}"
      update_delivery(delivery, "failed", error: error)
      unsubscribe_recipient(delivery, reason: "complaint")
    end
  end

  private

  def update_delivery(delivery, new_status, error: nil)
    return if status_superseded?(delivery.status, new_status)

    attrs = { status: new_status }
    attrs[:error] = error if error
    attrs[:completed_at] = Time.current if new_status.in?(%w[delivered failed])
    delivery.update!(attrs)

    update_message_status(delivery.message, new_status)
  end

  # update_message_status / status_superseded? provided by DeliveryStatusUpdating.

  def unsubscribe_recipient(delivery, reason: nil)
    email = Mail::Address.new(delivery.recipient).address&.downcase rescue return
    return unless email.present?

    customer = delivery.account.customers.find_by(email: email)
    customer&.unsubscribe_from!("email", reason: reason)
  end
end
