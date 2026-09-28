class Conversation < ApplicationRecord
  belongs_to :account
  belongs_to :environment
  belongs_to :customer, optional: true
  belongs_to :assigned_user, class_name: "User", optional: true

  has_many :conversation_messages, dependent: :destroy
  has_many :conversation_read_cursors, dependent: :destroy
  has_many :conversation_taggings, dependent: :destroy
  has_many :conversation_tags, through: :conversation_taggings
  has_many :conversation_assignments, dependent: :destroy
  has_one :email_thread, dependent: :destroy

  enum :status, { open: 0, pending: 1, snoozed: 2, resolved: 3, closed: 4 }
  enum :priority, { normal: 0, high: 1, urgent: 2 }
  enum :source, { widget: 0, api: 1, email: 2, whatsapp: 3 }, prefix: true

  validates :visitor_token, presence: true
  validates :status, presence: true

  scope :active, -> { where(status: [:open, :pending]) }
  scope :for_visitor, ->(token) { where(visitor_token: token) }
  scope :recent, -> { order(last_message_at: :desc, created_at: :desc) }
  scope :assigned_to, ->(user) { where(assigned_user_id: user.id) }
  scope :unassigned, -> { where(assigned_user_id: nil) }
  scope :email_tickets, -> { where(source: :email) }
  scope :chat_conversations, -> { where(source: [:widget, :api]) }

  # WhatsApp only allows free-form replies within 24h of the customer's last
  # message (the customer service window); outside it a template is required.
  WHATSAPP_SERVICE_WINDOW = 24.hours

  def whatsapp_window_expires_at
    return nil unless source_whatsapp?
    # Imported history never opens a window: only messages that reached the
    # number while it was on the Cloud API count.
    last = conversation_messages.where(sender_type: "Customer")
      .where.not("conversation_messages.metadata @> ?", { whatsapp: { history: true } }.to_json)
      .maximum(:created_at)
    last && last + WHATSAPP_SERVICE_WINDOW
  end

  def whatsapp_integration
    WhatsappIntegration.find_by(id: metadata&.dig("whatsapp_integration_id"), account_id: account_id)
  end

  def whatsapp_free_form_allowed?
    expires = whatsapp_window_expires_at
    expires.present? && expires > Time.current
  end

  after_create_commit :broadcast_new_conversation
  after_update_commit :broadcast_conversation_update

  def touch_last_message!(message)
    update!(
      last_message_at: message.created_at,
      last_message_preview: message.content&.truncate(100)
    )
  end

  def unread_count_for(user)
    cursor = conversation_read_cursors.find_by(reader_type: "User", reader_id: user.id)
    if cursor&.last_read_message_id
      conversation_messages.where(private: false)
        .where("id > ?", cursor.last_read_message_id)
        .where.not(sender_type: "User", sender_id: user.id)
        .count
    else
      conversation_messages.where(private: false)
        .where.not(sender_type: "User", sender_id: user.id)
        .count
    end
  end

  def unread_count_for_visitor
    cursor = conversation_read_cursors.find_by(reader_type: "Visitor")
    if cursor&.last_read_message_id
      conversation_messages.where(private: false)
        .where("id > ?", cursor.last_read_message_id)
        .where(sender_type: "User")
        .count
    else
      conversation_messages.where(private: false)
        .where(sender_type: "User")
        .count
    end
  end

  def as_inbox_json
    {
      id: id,
      visitor_name: visitor_name,
      visitor_email: visitor_email,
      status: status,
      priority: priority,
      source: source,
      subject: subject,
      ticket_number: ticket_number,
      assigned_user_id: assigned_user_id,
      last_message_at: last_message_at,
      last_message_preview: last_message_preview,
      visitor_page_url: visitor_page_url,
      visitor_last_seen_at: visitor_last_seen_at,
      created_at: created_at,
      customer_id: customer_id
    }
  end

  private

  def broadcast_new_conversation
    ActionCable.server.broadcast(
      "operator_inbox_#{account_id}",
      { type: "new_conversation", conversation: as_inbox_json }
    )
  end

  def broadcast_conversation_update
    ActionCable.server.broadcast(
      "operator_inbox_#{account_id}",
      { type: "conversation_update", conversation: as_inbox_json }
    )
  end
end
