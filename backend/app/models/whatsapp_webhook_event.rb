# One signed POST from Meta, stored verbatim for auditing and replay. The body
# digest dedupes Meta's retries of the exact same delivery before any work is queued.
class WhatsappWebhookEvent < ApplicationRecord
  belongs_to :account, optional: true
  belongs_to :integration, optional: true

  scope :failed, -> { where.not(error: nil) }
end
