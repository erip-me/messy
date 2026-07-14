class CreateConversationMessages < ActiveRecord::Migration[8.0]
  def change
    create_table :conversation_messages do |t|
      t.references :conversation, null: false, foreign_key: true
      t.references :account, null: false, foreign_key: true
      t.string :sender_type, null: false
      t.bigint :sender_id
      t.integer :message_type, null: false, default: 0
      t.text :content
      t.boolean :private, null: false, default: false
      t.jsonb :metadata, default: {}
      t.boolean :read_by_visitor, default: false
      t.boolean :read_by_operator, default: false
      t.timestamps
    end

    add_index :conversation_messages, [:conversation_id, :created_at]
    add_index :conversation_messages, [:sender_type, :sender_id]
  end
end
