# Re-arms cloud push for connected OAuth mailboxes before it lapses: Gmail
# watches (7-day cap) and Graph subscriptions (~3-day cap). Scheduled every few
# hours via recurring.yml. A mailbox that can't renew keeps working via the
# 2-minute poll, so failures are logged, not fatal.
class RenewMailboxPushJob < ApplicationJob
  queue_as :email_ingestion

  def perform
    Mailbox.active_mailboxes.oauth_mailboxes.find_each do |mailbox|
      next unless mailbox.connected? && mailbox.push_registered?

      push = mailbox.push_service
      next unless push

      push.renew!
    rescue => e
      Rails.logger.error "[RenewMailboxPushJob] Failed to renew push for mailbox #{mailbox.id}: #{e.message}"
    end
  end
end
