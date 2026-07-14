class CannedResponse < ApplicationRecord
  belongs_to :account
  belongs_to :created_by, class_name: "User", optional: true

  validates :shortcut, presence: true, uniqueness: { scope: :account_id }
  validates :title, presence: true
  validates :content, presence: true

  scope :search, ->(query) {
    where("shortcut ILIKE :q OR title ILIKE :q OR content ILIKE :q", q: "%#{query}%")
  }
end
