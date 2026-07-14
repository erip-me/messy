class ConversationTag < ApplicationRecord
  belongs_to :account

  has_many :conversation_taggings, dependent: :destroy
  has_many :conversations, through: :conversation_taggings

  validates :name, presence: true, uniqueness: { scope: :account_id }

  scope :quick_replies, -> { where(is_quick_reply: true).order(:sort_order) }
  scope :ordered, -> { order(:sort_order) }
end
