class CreateMailboxes < ActiveRecord::Migration[8.0]
  def change
    create_table :mailboxes do |t|
      t.references :account, null: false, foreign_key: true
      t.references :environment, null: false, foreign_key: true
      t.string :name, null: false
      t.string :email_address, null: false
      t.integer :provider, default: 0, null: false
      t.jsonb :config, default: {}
      t.jsonb :outbound_config, default: {}
      t.boolean :active, default: true, null: false
      t.datetime :last_synced_at
      t.jsonb :sync_state, default: {}
      t.string :ticket_prefix, default: ""
      t.integer :next_ticket_number, default: 1001, null: false
      t.boolean :auto_assign, default: true, null: false
      t.boolean :auto_reply_enabled, default: true, null: false
      t.text :auto_reply_template
      t.integer :auto_close_days
      t.jsonb :notification_events, default: {
        "ticket_created" => true,
        "ticket_assigned" => true,
        "ticket_reply_from_operator" => true,
        "ticket_closed" => true,
        "ticket_reopened" => true,
        "ticket_note_added" => false
      }
      t.timestamps
    end

    add_index :mailboxes, [:account_id, :email_address], unique: true
  end
end
