class PruneMessagesJob < ApplicationJob
  queue_as :default
  queue_with_priority 30

  BATCH_SIZE = 500

  def perform
    Account.where.not(message_retention_days: nil).find_each do |account|
      cutoff = account.message_retention_days.days.ago
      prune_messages(account, cutoff)
    end
  end

  private

  def purge_attachments(message_ids)
    attachments = ActiveStorage::Attachment.where(record_type: "Message", record_id: message_ids)
    attachments.each { |attachment| attachment.purge }
  end

  def prune_messages(account, cutoff)
    loop do
      message_ids = account.messages
        .where(parent_message_id: nil)
        .where("messages.created_at < ?", cutoff)
        .limit(BATCH_SIZE)
        .pluck(:id)

      break if message_ids.empty?

      child_ids = Message.where(parent_message_id: message_ids).pluck(:id)
      all_ids = message_ids + child_ids

      Delivery.where(message_id: all_ids).delete_all
      Open.where(message_id: all_ids).delete_all
      purge_attachments(all_ids)
      Message.where(id: child_ids).delete_all
      Message.where(id: message_ids).delete_all
    end
  end
end
