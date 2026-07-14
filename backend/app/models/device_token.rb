class DeviceToken < ApplicationRecord
  belongs_to :account
  belongs_to :customer

  enum :platform, { ios: 0, android: 1, web: 2 }, validate: true

  validates :token, presence: true, uniqueness: true
  validates :platform, presence: true

  scope :active, -> { where(active: true) }
  scope :for_platform, ->(p) { where(platform: p) }
  scope :for_app, ->(app_id) { where(app_id: app_id) }

  def deactivate!
    update!(active: false)
  end

  def touch_last_used!(at: Time.current)
    update_column(:last_used_at, at)
  end
end
