# Status history for a WhatsApp message (sent/delivered/read/failed), keyed by the
# Meta message id so it covers both inbox replies and API/campaign deliveries.
class WhatsappMessageStatus < ApplicationRecord
  belongs_to :account
end
