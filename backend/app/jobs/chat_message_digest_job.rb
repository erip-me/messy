class ChatMessageDigestJob < ApplicationJob
  queue_as :default

  DIGEST_INTERVALS = [15.minutes, 1.hour, 8.hours].freeze

  def perform
    Conversation.where(status: [:open, :pending])
                .where.not(visitor_email: [nil, ""])
                .includes(:account, :environment)
                .find_each do |conversation|
      next if visitor_currently_online?(conversation)

      unread_messages = conversation.conversation_messages
        .where(private: false, sender_type: "User")
        .where(read_by_visitor: false)
        .includes(sender: :operator_profile)
        .order(created_at: :asc)
        .to_a

      next if unread_messages.empty?

      last_digest_at = conversation.metadata["last_digest_at"]&.to_datetime
      interval_index = conversation.metadata["digest_interval_index"]&.to_i || 0
      interval = DIGEST_INTERVALS[[interval_index, DIGEST_INTERVALS.length - 1].min]

      if last_digest_at.nil? || last_digest_at < interval.ago
        send_digest(conversation, unread_messages)

        conversation.update!(metadata: conversation.metadata.merge(
          "last_digest_at" => Time.current.iso8601,
          "digest_interval_index" => [interval_index + 1, DIGEST_INTERVALS.length - 1].min
        ))
      end
    end
  end

  private

  def send_digest(conversation, messages)
    account = conversation.account
    environment = conversation.environment

    message_lines = messages.map { |m| "<p><strong>#{m.sender_name}:</strong> #{m.content}</p>" }.join

    EmailMessage.create!(
      account: account,
      environment: environment,
      to: conversation.visitor_email,
      subject: "You have #{messages.length} unread #{'message'.pluralize(messages.length)} from #{account.name}",
      body: "<p>You have unread messages in your conversation:</p>#{message_lines}<p>Reply by visiting our chat.</p>"
    ).tap { |msg| ProcessMessageJob.perform_later(msg) }
  end

  def visitor_currently_online?(conversation)
    conversation.visitor_last_seen_at.present? && conversation.visitor_last_seen_at > 2.minutes.ago
  end
end
