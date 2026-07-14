class AddAccountIdToDeliveriesOpensWebhookLogsAndWebhookSinks < ActiveRecord::Migration[7.1]
  def change
    add_reference :deliveries, :account, foreign_key: true, null: true
    add_reference :opens, :account, foreign_key: true, null: true
    add_reference :webhook_logs, :account, foreign_key: true, null: true
    add_reference :webhook_sinks, :account, foreign_key: true, null: true

    reversible do |dir|
      dir.up do
        execute <<~SQL
          UPDATE deliveries SET account_id = messages.account_id
          FROM messages WHERE deliveries.message_id = messages.id;
        SQL

        execute <<~SQL
          UPDATE opens SET account_id = messages.account_id
          FROM messages WHERE opens.message_id = messages.id;
        SQL

        execute <<~SQL
          UPDATE webhook_logs SET account_id = webhooks.account_id
          FROM webhooks WHERE webhook_logs.webhook_id = webhooks.id;
        SQL

        execute <<~SQL
          UPDATE webhook_sinks SET account_id = webhooks.account_id
          FROM webhooks WHERE webhook_sinks.webhook_id = webhooks.id;
        SQL
      end
    end

    change_column_null :deliveries, :account_id, false
    change_column_null :opens, :account_id, false
    change_column_null :webhook_logs, :account_id, false
    change_column_null :webhook_sinks, :account_id, false
  end
end
