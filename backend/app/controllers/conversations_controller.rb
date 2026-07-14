class ConversationsController < ApplicationController
  include ApiAuthentication

  # The operator inbox exposes account-wide conversations (visitor PII, IPs, email
  # bodies) across every environment. It must require a logged-in dashboard operator
  # (JWT), not a lower-trust per-environment API key. The widget uses a separate
  # Widget::ConversationsController, so this does not affect end-user chat.
  before_action :require_operator!
  before_action :find_conversation, only: [:show, :messages, :create_message, :update, :assign, :transfer, :snooze, :mark_read, :mark_unread, :add_tag, :remove_tag, :email_detail]

  rescue_from ActiveRecord::RecordNotFound, with: :render_404

  def index
    conversations = @account.conversations

    # Filter by source (chat vs email tickets)
    if params[:source].present?
      conversations = conversations.where(source: params[:source])
    end

    # Filter by status
    if params[:status].present?
      conversations = conversations.where(status: params[:status])
    else
      conversations = conversations.where(status: [:open, :pending])
    end

    # Filter by assignment
    if params[:assigned_to] == "me"
      conversations = conversations.assigned_to(current_user)
    elsif params[:assigned_to] == "unassigned"
      conversations = conversations.unassigned
    end

    # Search
    if params[:q].present?
      q = "%#{params[:q]}%"
      conversations = conversations.where(
        "visitor_name ILIKE ? OR visitor_email ILIKE ? OR subject ILIKE ? OR ticket_number ILIKE ?", q, q, q, q
      )
    end

    page = (params[:page] || 1).to_i
    per_page = [params[:per_page]&.to_i || 25, 50].min
    total = conversations.count

    conversations = conversations.recent
                                 .offset((page - 1) * per_page)
                                 .limit(per_page)
                                 .includes(:customer, :conversation_read_cursors, :conversation_tags, :email_thread, assigned_user: :operator_profile)

    unread_counts = current_user ? bulk_unread_counts(conversations) : {}

    render json: {
      conversations: ConversationResource.new(conversations, params: { unread_counts: unread_counts }).to_h,
      total: total,
      page: page,
      total_pages: (total.to_f / per_page).ceil
    }
  end

  def show
    messages = @conversation.conversation_messages
                            .reverse_chronological
                            .limit(50)

    render json: {
      conversation: detail_json(@conversation),
      messages: messages.reverse.map(&:as_chat_json),
      customer: @conversation.customer ? InboxCustomerResource.new(@conversation.customer).to_h : nil
    }
  end

  def messages
    messages = @conversation.conversation_messages.reverse_chronological

    if params[:before].present?
      messages = messages.where("id < ?", params[:before])
    end

    limit = [params[:limit]&.to_i || 50, 100].min
    messages = messages.limit(limit + 1).to_a

    has_more = messages.length > limit
    messages = messages.first(limit)

    render json: {
      messages: messages.reverse.map(&:as_chat_json),
      has_more: has_more
    }
  end

  def create_message
    has_files = params[:attachments].present?
    message = @conversation.conversation_messages.new(
      account: @account,
      sender_type: "User",
      sender_id: current_user.id,
      message_type: params[:private] ? :note : :text,
      content: params[:content],
      private: params[:private] || false
    )

    if has_files
      Array(params[:attachments]).each { |f| message.attachments.attach(f) }
    end

    message.save!

    if @conversation.source_email? && !message.private && message.sender_type == "User"
      SendEmailReplyJob.perform_later(message.id)
    end

    render json: { message: message.as_chat_json }, status: :created
  end

  def email_detail
    message = @conversation.conversation_messages.find(params[:message_id])
    detail = message.email_message_detail

    render json: {
      email_detail: detail ? {
        html_body: detail.html_body,
        text_body: detail.text_body,
        from_email: detail.from_email,
        from_name: detail.from_name,
        to_email: detail.to_email,
        cc_list: detail.cc_list,
        message_id_header: detail.message_id_header,
        created_at: detail.created_at
      } : nil
    }
  end

  def update
    old_status = @conversation.status
    @conversation.update!(conversation_params)

    if @conversation.source_email? && old_status != @conversation.status
      if @conversation.status.in?(%w[resolved closed])
        SendTicketNotificationJob.perform_later(@conversation.id, "ticket_closed")
      end
    end

    render json: { conversation: detail_json(@conversation) }
  end

  def assign
    user = @account.users.find(params[:user_id])
    @conversation.update!(assigned_user: user)
    ConversationAssignment.create!(
      conversation: @conversation,
      assigned_by: current_user,
      assigned_to: user
    )

    @conversation.conversation_messages.create!(
      account: @account,
      sender_type: "System",
      message_type: :system,
      content: "Conversation assigned to #{user.operator_profile&.public_name || user.name} by #{current_user.name}"
    )

    UserMailer.with(user: user, conversation: @conversation, assigned_by: current_user).conversation_assigned.deliver_later

    if @conversation.source_email?
      SendTicketNotificationJob.perform_later(@conversation.id, "ticket_assigned")
    end

    render json: { conversation: detail_json(@conversation) }
  end

  def transfer
    user = @account.users.find(params[:user_id])
    old_user = @conversation.assigned_user

    @conversation.update!(assigned_user: user)
    ConversationAssignment.create!(
      conversation: @conversation,
      assigned_by: current_user,
      assigned_to: user
    )

    note = params[:note].present? ? " Note: #{params[:note]}" : ""
    @conversation.conversation_messages.create!(
      account: @account,
      sender_type: "System",
      message_type: :system,
      content: "Conversation transferred from #{old_user&.name || 'unassigned'} to #{user.operator_profile&.public_name || user.name}.#{note}"
    )

    UserMailer.with(user: user, conversation: @conversation, assigned_by: current_user).conversation_assigned.deliver_later

    render json: { conversation: detail_json(@conversation) }
  end

  def snooze
    @conversation.update!(status: :snoozed, snoozed_until: params[:until])
    render json: { conversation: detail_json(@conversation) }
  end

  def mark_read
    last_message = @conversation.conversation_messages.order(id: :desc).first
    return head :ok unless last_message

    cursor = ConversationReadCursor.find_or_initialize_by(
      conversation: @conversation, reader_type: "User", reader_id: current_user.id
    )
    cursor.update!(last_read_message_id: last_message.id, last_read_at: Time.current)

    @conversation.conversation_messages
      .where("id <= ?", last_message.id)
      .where(read_by_operator: false)
      .update_all(read_by_operator: true)

    head :ok
  end

  def mark_unread
    cursor = ConversationReadCursor.find_by(
      conversation: @conversation, reader_type: "User", reader_id: current_user.id
    )

    if cursor
      # Reset cursor to before the last non-operator message, so it shows as unread
      last_incoming = @conversation.conversation_messages
        .where.not(sender_type: "User")
        .where(private: false)
        .order(id: :desc)
        .first

      if last_incoming
        # Set cursor to just before this message
        prev_id = @conversation.conversation_messages
          .where("id < ?", last_incoming.id)
          .order(id: :desc)
          .pick(:id) || 0

        cursor.update!(last_read_message_id: prev_id, last_read_at: Time.current)

        @conversation.conversation_messages
          .where("id >= ?", last_incoming.id)
          .where(read_by_operator: true)
          .update_all(read_by_operator: false)
      else
        cursor.destroy!
        @conversation.conversation_messages.where(read_by_operator: true).update_all(read_by_operator: false)
      end
    end

    head :ok
  end

  def add_tag
    tag = @account.conversation_tags.find(params[:tag_id])
    @conversation.conversation_tags << tag unless @conversation.conversation_tags.include?(tag)
    render json: { tags: @conversation.conversation_tags.map { |t| { id: t.id, name: t.name } } }
  end

  def remove_tag
    tagging = @conversation.conversation_taggings.find_by(conversation_tag_id: params[:tag_id])
    tagging&.destroy!
    render json: { tags: @conversation.conversation_tags.reload.map { |t| { id: t.id, name: t.name } } }
  end

  def search
    q = "%#{params[:q]}%"
    conversations = @account.conversations
      .joins(:conversation_messages)
      .where("conversation_messages.content ILIKE ? OR conversations.visitor_name ILIKE ? OR conversations.visitor_email ILIKE ?", q, q, q)
      .distinct
      .recent
      .limit(25)
      .includes(:customer, :conversation_read_cursors, :conversation_tags, assigned_user: :operator_profile)

    unread_counts = current_user ? bulk_unread_counts(conversations) : {}

    render json: { conversations: ConversationResource.new(conversations, params: { unread_counts: unread_counts }).to_h }
  end

  def stats
    convos = @account.conversations
    uid = current_user.id

    status_counts = convos.group(:status).count

    # Single grouped query for unread per assignment bucket
    unread_by_assignee = convos.where(status: [:open, :pending])
      .joins(ActiveRecord::Base.sanitize_sql_array([
        "LEFT JOIN conversation_read_cursors ON conversation_read_cursors.conversation_id = conversations.id AND conversation_read_cursors.reader_type = 'User' AND conversation_read_cursors.reader_id = ?", uid
      ]))
      .where(
        "EXISTS (SELECT 1 FROM conversation_messages cm WHERE cm.conversation_id = conversations.id AND cm.private = false AND NOT (cm.sender_type = 'User' AND cm.sender_id = ?) AND cm.id > COALESCE(conversation_read_cursors.last_read_message_id, 0))", uid
      )
      .group(:assigned_user_id)
      .count

    unread_mine = unread_by_assignee[uid] || 0
    unread_unassigned = unread_by_assignee[nil] || 0
    unread_total = unread_by_assignee.values.sum

    render json: {
      open: status_counts["open"] || 0,
      pending: status_counts["pending"] || 0,
      snoozed: status_counts["snoozed"] || 0,
      unread: unread_total,
      unread_mine: unread_mine,
      unread_unassigned: unread_unassigned,
      resolved_today: convos.where(status: :resolved).where("resolved_at >= ?", Time.current.beginning_of_day).count,
      avg_first_response_seconds: convos.where.not(first_response_at: nil).average("EXTRACT(EPOCH FROM first_response_at - created_at)")&.round
    }
  end

  private

  def detail_json(conversation)
    ConversationDetailResource.new(conversation, params: { current_user: current_user }).to_h
  end

  def require_operator!
    render json: { error: "Unauthorized" }, status: :unauthorized unless current_user
  end

  def find_conversation
    @conversation = @account.conversations.includes(email_thread: :mailbox).find(params[:id])
  end

  def conversation_params
    params.permit(:status, :priority)
  end

  def bulk_unread_counts(conversations)
    return {} unless current_user

    conversation_ids = conversations.map(&:id)
    return {} if conversation_ids.empty?

    rows = ConversationMessage
      .where(conversation_id: conversation_ids, private: false)
      .where.not(sender_type: "User", sender_id: current_user.id)
      .joins(
        "LEFT JOIN conversation_read_cursors crc ON crc.conversation_id = conversation_messages.conversation_id " \
        "AND crc.reader_type = 'User' AND crc.reader_id = #{current_user.id}"
      )
      .where("conversation_messages.id > COALESCE(crc.last_read_message_id, 0)")
      .group(:conversation_id)
      .count

    rows
  end

end
