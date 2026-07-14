class ConversationChannel < ApplicationCable::Channel
  def subscribed
    @conversation = find_conversation
    reject and return unless @conversation

    stream_from "conversation_#{@conversation.id}"
  end

  def typing(data)
    conversation = find_conversation
    return unless conversation

    sender_info = if current_user
      { type: "operator", id: current_user.id, name: current_user.operator_profile&.public_name || current_user.name }
    else
      { type: "visitor", token: visitor_token }
    end

    ActionCable.server.broadcast(
      "conversation_#{conversation.id}",
      { type: "typing", sender: sender_info, is_typing: data["is_typing"] }
    )
  end

  def mark_read(data)
    conversation = find_conversation
    return unless conversation

    message_id = data["message_id"]
    if current_user
      cursor = ConversationReadCursor.find_or_initialize_by(
        conversation: conversation, reader_type: "User", reader_id: current_user.id
      )
    else
      cursor = ConversationReadCursor.find_or_initialize_by(
        conversation: conversation, reader_type: "Visitor", reader_id: nil
      )
    end
    cursor.update!(last_read_message_id: message_id, last_read_at: Time.current)

    read_column = current_user ? :read_by_operator : :read_by_visitor
    conversation.conversation_messages
      .where("id <= ?", message_id)
      .where(read_column => false)
      .update_all(read_column => true)

    ActionCable.server.broadcast(
      "conversation_#{conversation.id}",
      { type: "read_receipt", reader_type: cursor.reader_type, reader_id: cursor.reader_id, message_id: message_id }
    )
  end

  private

  def find_conversation
    if current_user
      Conversation.where(account_id: current_user.account_id).find_by(id: params[:conversation_id])
    elsif visitor_token && account_id
      Conversation.find_by(account_id: account_id, visitor_token: visitor_token, id: params[:conversation_id])
    end
  end
end
