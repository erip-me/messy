class AddAttachmentsToWebhookLogs < ActiveRecord::Migration[7.1]
  def change
    add_column :webhook_logs, :attachments, :jsonb, default: [], null: false
  end
end
