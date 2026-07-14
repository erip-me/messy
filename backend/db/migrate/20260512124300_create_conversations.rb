class CreateConversations < ActiveRecord::Migration[8.0]
  def change
    create_table :conversations do |t|
      t.references :account, null: false, foreign_key: true
      t.references :environment, null: false, foreign_key: true
      t.references :customer, foreign_key: true
      t.string :visitor_token, null: false
      t.string :visitor_name
      t.string :visitor_email
      t.references :assigned_user, foreign_key: { to_table: :users }
      t.integer :status, null: false, default: 0
      t.integer :priority, default: 0
      t.string :subject
      t.integer :source, default: 0
      t.datetime :last_message_at
      t.string :last_message_preview
      t.datetime :last_operator_reply_at
      t.datetime :visitor_last_seen_at
      t.datetime :snoozed_until
      t.datetime :first_response_at
      t.datetime :resolved_at
      t.integer :rating
      t.text :rating_comment
      t.string :visitor_page_url
      t.string :visitor_page_title
      t.text :visitor_user_agent
      t.string :visitor_ip
      t.string :visitor_country
      t.jsonb :metadata, default: {}
      t.timestamps
    end

    add_index :conversations, [:account_id, :status]
    add_index :conversations, [:account_id, :assigned_user_id, :status]
    add_index :conversations, [:account_id, :last_message_at], order: { last_message_at: :desc }
    add_index :conversations, [:visitor_token, :account_id]
    add_index :conversations, :snoozed_until, where: "snoozed_until IS NOT NULL"
  end
end
