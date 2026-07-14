class SendTranscriptJob < ApplicationJob
  queue_as :default

  def perform(conversation_id)
    conversation = Conversation.find(conversation_id)
    return unless conversation.visitor_email.present?

    account = conversation.account
    environment = conversation.environment
    messages = conversation.conversation_messages
                           .visible_to_visitor
                           .chronological

    return if messages.empty?

    transcript = messages.map { |m|
      time = m.created_at.strftime("%H:%M")
      "<p><strong>[#{time}] #{m.sender_name}:</strong> #{m.content}</p>"
    }.join

    EmailMessage.create!(
      account: account,
      environment: environment,
      to: conversation.visitor_email,
      subject: "Chat transcript from #{account.name}",
      body: "<h2>Chat Transcript</h2><p>Date: #{conversation.created_at.strftime('%B %d, %Y')}</p><hr>#{transcript}<hr><p>Thank you for chatting with us!</p>"
    ).tap { |msg| ProcessMessageJob.perform_later(msg) }
  end
end
