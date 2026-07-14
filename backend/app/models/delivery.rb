class Delivery < ApplicationRecord
  belongs_to :account
  belongs_to :message
  belongs_to :integration

  validates :recipient, presence: true
  validates :provider_message_id, uniqueness: true, allow_nil: true
end
