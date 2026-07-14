# Shared delivery-status transition logic for provider webhook jobs (SES,
# WhatsApp, ...). Each including job defines its own STATUS_RANK constant
# describing provider-specific ordering; this concern enforces forward-only
# transitions and maps a terminal provider status onto the Message lifecycle.
module DeliveryStatusUpdating
  extend ActiveSupport::Concern

  # True when new_status is not strictly newer than current_status, so an
  # out-of-order webhook can't regress a delivery (e.g. "sent" after "delivered").
  def status_superseded?(current_status, new_status)
    return false if current_status.blank?
    rank = self.class::STATUS_RANK
    (rank[current_status] || -1) >= (rank[new_status] || -1)
  end

  # Map a provider status onto the Message lifecycle. "read" (WhatsApp) is treated
  # as delivered; SES never emits it, so this is safe for both.
  def update_message_status(message, provider_status)
    case provider_status
    when "delivered", "read"
      message.update!(status: :delivered) if message.sent?
    when "failed"
      message.update!(status: :failed) unless message.failed?
    end
  end
end
