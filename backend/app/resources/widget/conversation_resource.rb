module Widget
  # What the embeddable chat widget sees of a conversation (visitor-facing).
  class ConversationResource
    include Alba::Resource

    attributes :id, :status, :subject, :last_message_at, :last_message_preview,
               :created_at

    attribute :assigned_operator do |conversation|
      conversation.assigned_user&.operator_profile&.as_public_json
    end

    attribute :unread_count do |conversation|
      conversation.unread_count_for_visitor
    end
  end
end
