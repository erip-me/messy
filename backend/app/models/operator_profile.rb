class OperatorProfile < ApplicationRecord
  HEARTBEAT_TTL = 90.seconds

  belongs_to :user
  belongs_to :account

  has_one_attached :avatar

  enum :availability, { online: 0, away: 1, offline: 2 }

  validates :public_name, presence: true
  validates :user_id, uniqueness: true
  validates :max_concurrent_chats, numericality: { greater_than: 0 }

  scope :available, -> {
    where(availability: :online, auto_assign: true)
      .where("last_heartbeat_at > ?", HEARTBEAT_TTL.ago)
  }

  def currently_online?
    online? && last_heartbeat_at.present? && last_heartbeat_at > HEARTBEAT_TTL.ago
  end

  def heartbeat!
    update!(last_heartbeat_at: Time.current)
  end

  def open_conversation_count
    Conversation.where(account_id: account_id, assigned_user_id: user_id)
                .where(status: [:open, :pending]).count
  end

  def at_capacity?
    open_conversation_count >= max_concurrent_chats
  end

  def avatar_url
    avatar.attached? ? Rails.application.routes.url_helpers.rails_blob_url(avatar) : nil
  end

  def display_name
    public_name.presence || user.name
  end

  def as_public_json
    {
      id: user_id,
      name: public_name,
      bio: bio,
      avatar_url: avatar_url,
      online: currently_online?
    }
  end
end
