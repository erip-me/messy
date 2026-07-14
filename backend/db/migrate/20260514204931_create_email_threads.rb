class CreateEmailThreads < ActiveRecord::Migration[8.0]
  def change
    create_table :email_threads do |t|
      t.references :account, null: false, foreign_key: true
      t.references :mailbox, null: false, foreign_key: true
      t.references :conversation, null: false, foreign_key: true, index: false
      t.string :ticket_number, null: false
      t.string :from_email, null: false
      t.string :from_name
      t.string :subject
      t.string :in_reply_to
      t.text :references_header
      t.jsonb :cc_list, default: []
      t.timestamps
    end

    add_index :email_threads, :conversation_id, unique: true
    add_index :email_threads, [:account_id, :ticket_number], unique: true
    add_index :email_threads, :in_reply_to
  end
end
