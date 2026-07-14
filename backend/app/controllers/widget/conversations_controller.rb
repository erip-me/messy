module Widget
  class ConversationsController < BaseController
    before_action :find_conversation, only: [:messages, :create_message, :mark_read, :rate]

    def index
      conversations = Conversation.where(account: @account, visitor_token: @visitor_token)
                                  .recent
                                  .limit(20)
                                  .to_a

      unread = bulk_unread_counts_for_visitor(conversations.map(&:id))

      render json: {
        conversations: conversations.map { |c|
          {
            id: c.id,
            status: c.status,
            subject: c.subject,
            last_message_at: c.last_message_at,
            last_message_preview: c.last_message_preview,
            unread_count: unread[c.id] || 0,
            created_at: c.created_at
          }
        }
      }
    end

    def create
      find_or_create_customer
      environment = @account.environments.where(is_deleted: false).first

      tag = @account.conversation_tags.find_by(id: params[:tag_id]) if params[:tag_id].present?

      conversation = Conversation.create!(
        account: @account,
        environment: environment,
        customer: @customer,
        visitor_token: @visitor_token,
        visitor_name: @customer.first_name || generate_visitor_name,
        visitor_email: @customer.email,
        status: :open,
        source: :widget,
        subject: tag&.name,
        visitor_page_url: params[:page_url],
        visitor_page_title: params[:page_title],
        visitor_ip: request.remote_ip,
        visitor_user_agent: request.user_agent
      )

      conversation.conversation_tags << tag if tag

      if params[:initial_message].present?
        conversation.conversation_messages.create!(
          account: @account,
          sender_type: "Customer",
          sender_id: @customer.id,
          message_type: :text,
          content: params[:initial_message]
        )
      end

      assigned_user = ConversationAutoAssigner.assign(conversation)
      if assigned_user
        UserMailer.with(user: assigned_user, conversation: conversation).conversation_assigned.deliver_later
      end

      render json: { conversation: Widget::ConversationResource.new(conversation).to_h }, status: :created
    end

    def messages
      messages = @conversation.conversation_messages
                              .visible_to_visitor
                              .reverse_chronological

      if params[:before].present?
        messages = messages.where("id < ?", params[:before])
      end

      limit = [params[:limit]&.to_i || 20, 50].min
      messages = messages.limit(limit + 1).to_a

      has_more = messages.length > limit
      messages = messages.first(limit)

      render json: {
        messages: messages.reverse.map(&:as_chat_json),
        has_more: has_more
      }
    end

    def create_message
      return if reject_invalid_attachments!
      find_or_create_customer

      message = @conversation.conversation_messages.create!(
        account: @account,
        sender_type: "Customer",
        sender_id: @customer.id,
        message_type: params[:attachments].present? ? :attachment : :text,
        content: params[:content]
      )

      if params[:attachments].present?
        Array(params[:attachments]).each do |file|
          message.attachments.attach(file)
        end
      end

      render json: { message: message.as_chat_json }, status: :created
    end

    def mark_read
      message_id = params[:message_id]
      cursor = ConversationReadCursor.find_or_initialize_by(
        conversation: @conversation,
        reader_type: "Visitor",
        reader_id: nil
      )
      cursor.update!(last_read_message_id: message_id, last_read_at: Time.current)

      @conversation.conversation_messages
        .where("id <= ?", message_id)
        .where(read_by_visitor: false)
        .update_all(read_by_visitor: true)

      ActionCable.server.broadcast(
        "conversation_#{@conversation.id}",
        { type: "read_receipt", reader_type: "Visitor", message_id: message_id }
      )

      head :ok
    end

    def rate
      @conversation.update!(
        rating: params[:rating],
        rating_comment: params[:comment]
      )

      render json: { success: true }
    end

    private

    # Public widget uploads are visitor-supplied; restrict type and size so the
    # endpoint can't be used to store arbitrary/huge files.
    ALLOWED_ATTACHMENT_TYPES = %w[
      image/png image/jpeg image/gif image/webp application/pdf
      text/plain text/csv application/zip
      application/msword
      application/vnd.openxmlformats-officedocument.wordprocessingml.document
    ].freeze
    MAX_ATTACHMENT_BYTES = 10.megabytes

    # Renders a 422 and returns true if any attachment is too large or a
    # disallowed type; returns false when all attachments are acceptable.
    def reject_invalid_attachments!
      Array(params[:attachments]).reject(&:blank?).each do |file|
        next unless file.respond_to?(:content_type) && file.respond_to?(:size)

        if file.size.to_i > MAX_ATTACHMENT_BYTES
          render json: { error: "Attachment too large (max 10 MB)" }, status: :unprocessable_entity
          return true
        end
        unless ALLOWED_ATTACHMENT_TYPES.include?(file.content_type)
          render json: { error: "Attachment type not allowed" }, status: :unprocessable_entity
          return true
        end
      end
      false
    end

    # Visitor unread counts for many conversations in one query (mirrors the
    # operator ConversationsController#bulk_unread_counts). Unread = operator
    # ("User") messages past the visitor's read cursor. Avoids the per-row
    # find_by + count that ran on every widget open.
    def bulk_unread_counts_for_visitor(conversation_ids)
      return {} if conversation_ids.empty?

      ConversationMessage
        .where(conversation_id: conversation_ids, private: false, sender_type: "User")
        .joins(
          "LEFT JOIN conversation_read_cursors crc ON crc.conversation_id = conversation_messages.conversation_id " \
          "AND crc.reader_type = 'Visitor' AND crc.reader_id IS NULL"
        )
        .where("conversation_messages.id > COALESCE(crc.last_read_message_id, 0)")
        .group(:conversation_id)
        .count
    end

    def find_conversation
      @conversation = Conversation.find_by!(
        id: params[:id] || params[:conversation_id],
        account: @account,
        visitor_token: @visitor_token
      )
    end

  end
end
