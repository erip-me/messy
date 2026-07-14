class PollAllMailboxesJob < ApplicationJob
  queue_as :email_ingestion

  def perform
    Mailbox.active_mailboxes.find_each do |mailbox|
      PollMailboxJob.perform_later(mailbox.id)
    end
  end
end
