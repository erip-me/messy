class CreateWebhookLogs < ActiveRecord::Migration[7.1]
  def change
    create_table :webhook_logs do |t|
      t.references :webhook, null: false, foreign_key: true
      t.string :request_ip, null: false
      t.string :method, null: false
      t.jsonb :headers, null: false
      t.jsonb :body
      t.jsonb :query
      t.jsonb :sinks, default: [], null: false
      t.datetime :received_at

      t.timestamps
    end
  end
end
