class ConversationMessage < ApplicationRecord
  belongs_to :conversation
  belongs_to :account
  belongs_to :sender, polymorphic: true, optional: true

  has_many_attached :attachments
  has_one :email_message_detail, dependent: :destroy

  enum :message_type, { text: 0, attachment: 1, system: 2, note: 3 }

  validates :content, presence: true, unless: :has_attachments?
  validates :sender_type, inclusion: { in: %w[User Customer System] }

  after_create_commit :update_conversation_timestamp
  after_create_commit :broadcast_message

  scope :visible_to_visitor, -> { where(private: false) }
  scope :chronological, -> { order(created_at: :asc) }
  scope :reverse_chronological, -> { order(created_at: :desc) }

  def sender_name
    case sender_type
    when "User"
      sender&.operator_profile&.public_name || sender&.name || "Operator"
    when "Customer"
      conversation&.visitor_name || "Visitor"
    when "System"
      "System"
    end
  end

  def as_chat_json
    {
      id: id,
      conversation_id: conversation_id,
      sender_type: sender_type,
      sender_id: sender_id,
      sender_name: sender_name,
      message_type: message_type,
      content: content,
      private: self.private,
      metadata: metadata,
      read_by_visitor: read_by_visitor,
      read_by_operator: read_by_operator,
      attachments: attachments.map { |a| { id: a.id, filename: a.filename.to_s, content_type: a.content_type, byte_size: a.byte_size, url: Rails.application.routes.url_helpers.rails_blob_url(a) } },
      created_at: created_at
    }
  end

  private

  def has_attachments?
    attachments.attached?
  end

  def update_conversation_timestamp
    attrs = {
      last_message_at: created_at,
      last_message_preview: content&.truncate(100)
    }

    if sender_type == "User" && !self.private
      attrs[:last_operator_reply_at] = created_at
      attrs[:first_response_at] = created_at if conversation.first_response_at.nil?
    end

    conversation.update!(attrs)
  end

  def broadcast_message
    json = as_chat_json

    unless self.private
      ActionCable.server.broadcast(
        "conversation_#{conversation_id}",
        { type: "new_message", message: json }
      )
    end

    ActionCable.server.broadcast(
      "operator_inbox_#{account_id}",
      { type: "new_message", conversation_id: conversation_id, message: json }
    )
  end
end
