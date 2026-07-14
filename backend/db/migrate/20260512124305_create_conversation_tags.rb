class CreateConversationTags < ActiveRecord::Migration[8.0]
  def change
    create_table :conversation_tags do |t|
      t.references :account, null: false, foreign_key: true
      t.string :name, null: false
      t.string :color, default: "#6B7280"
      t.boolean :is_quick_reply, default: false
      t.integer :sort_order, default: 0
      t.timestamps
    end

    add_index :conversation_tags, [:account_id, :name], unique: true

    create_table :conversation_taggings do |t|
      t.references :conversation, null: false, foreign_key: true
      t.references :conversation_tag, null: false, foreign_key: true
      t.datetime :created_at, null: false
    end

    add_index :conversation_taggings, [:conversation_id, :conversation_tag_id],
              unique: true, name: "idx_conv_taggings_unique"
  end
end
