class ConversationTagging < ApplicationRecord
  belongs_to :conversation
  belongs_to :conversation_tag

  validates :conversation_tag_id, uniqueness: { scope: :conversation_id }
end
