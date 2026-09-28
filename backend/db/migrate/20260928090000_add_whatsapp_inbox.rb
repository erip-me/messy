# WhatsApp Cloud API inbox (incl. Business App coexistence): raw webhook audit log,
# Meta message ids on inbox messages, per-message status history, and a stable
# WhatsApp id on customers. Unique indexes are the idempotency guarantee — Meta
# retries webhooks, and a replay must never create a second row.
class AddWhatsappInbox < ActiveRecord::Migration[8.0]
  def change
    create_table :whatsapp_webhook_events do |t|
      t.references :account, foreign_key: { on_delete: :cascade }
      t.references :integration, foreign_key: { on_delete: :nullify }
      t.string :body_sha256, null: false
      t.jsonb :payload, null: false
      t.datetime :processed_at
      t.text :error
      t.timestamps
    end
    add_index :whatsapp_webhook_events, :body_sha256, unique: true
    add_index :whatsapp_webhook_events, [:integration_id, :created_at]

    create_table :whatsapp_message_statuses do |t|
      t.references :account, null: false, foreign_key: { on_delete: :cascade }
      t.string :wamid, null: false
      t.string :status, null: false
      t.datetime :occurred_at
      t.jsonb :payload, null: false, default: {}
      t.timestamps
    end
    add_index :whatsapp_message_statuses, [:wamid, :status], unique: true

    add_column :conversation_messages, :external_id, :string
    add_column :conversation_messages, :delivery_status, :string
    add_index :conversation_messages, [:account_id, :external_id], unique: true,
              where: "external_id IS NOT NULL"

    add_column :customers, :whatsapp_id, :string
    add_index :customers, [:account_id, :whatsapp_id], unique: true,
              where: "whatsapp_id IS NOT NULL"

    # One WhatsApp thread per (business number, contact); source 3 = whatsapp.
    add_index :conversations, [:account_id, :visitor_token], unique: true,
              where: "source = 3", name: "index_conversations_whatsapp_thread_unique"
  end
end
