class RemoveWebhooksFeature < ActiveRecord::Migration[8.0]
  # Removes the incoming-webhooks feature (webhooks + sinks + request logs) and
  # the messages.webhook_id link. Destructive: the data is dropped, not archived.
  def up
    remove_foreign_key :messages, :webhooks if foreign_key_exists?(:messages, :webhooks)
    remove_column :messages, :webhook_id, if_exists: true

    drop_table :webhook_logs, if_exists: true
    drop_table :webhook_sinks, if_exists: true
    drop_table :webhooks, if_exists: true
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
