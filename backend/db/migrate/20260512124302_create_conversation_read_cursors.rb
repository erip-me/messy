class CreateConversationReadCursors < ActiveRecord::Migration[8.0]
  def change
    create_table :conversation_read_cursors do |t|
      t.references :conversation, null: false, foreign_key: true
      t.string :reader_type, null: false
      t.bigint :reader_id
      t.references :last_read_message, foreign_key: { to_table: :conversation_messages }
      t.datetime :last_read_at
      t.timestamps
    end

    add_index :conversation_read_cursors, [:conversation_id, :reader_type, :reader_id],
              unique: true, name: "idx_conv_read_cursors_unique"
  end
end
