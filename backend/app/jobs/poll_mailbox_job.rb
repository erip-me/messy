class PollMailboxJob < ApplicationJob
  queue_as :email_ingestion

  def perform(mailbox_id)
    mailbox = Mailbox.find_by(id: mailbox_id)
    return unless mailbox&.active?

    fetcher = mailbox.fetcher
    return unless fetcher

    emails = fetcher.fetch_new_emails

    emails.each do |mail_msg, uid|
      EmailIngestion::Processor.new(mailbox, mail_msg, provider_uid: uid).process!
    rescue => e
      Rails.logger.error "[PollMailboxJob] Failed to process email UID=#{uid} for mailbox #{mailbox_id}: #{e.message}"
    end
  end
end
