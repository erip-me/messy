class ConversationReadCursor < ApplicationRecord
  belongs_to :conversation
  belongs_to :last_read_message, class_name: "ConversationMessage", optional: true

  validates :reader_type, presence: true, inclusion: { in: %w[User Visitor] }
  validates :conversation_id, uniqueness: { scope: [:reader_type, :reader_id] }
end
