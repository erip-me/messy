module Widget
  class UnreadController < BaseController
    def show
      conversation_ids = Conversation.where(account: @account, visitor_token: @visitor_token)
                                     .where(status: [:open, :pending])
                                     .pluck(:id)

      if conversation_ids.empty?
        render json: { count: 0 }
        return
      end

      total_unread = ConversationMessage
        .where(conversation_id: conversation_ids, private: false, sender_type: "User")
        .where(
          "id > COALESCE((SELECT last_read_message_id FROM conversation_read_cursors " \
          "WHERE conversation_read_cursors.conversation_id = conversation_messages.conversation_id " \
          "AND reader_type = 'Visitor' LIMIT 1), 0)"
        )
        .count

      render json: { count: total_unread }
    end
  end
end
