class EmailMessageDetail < ApplicationRecord
  belongs_to :conversation_message

  validates :conversation_message_id, uniqueness: true
end
