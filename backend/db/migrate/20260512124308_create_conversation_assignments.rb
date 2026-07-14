class CreateConversationAssignments < ActiveRecord::Migration[8.0]
  def change
    create_table :conversation_assignments do |t|
      t.references :conversation, null: false, foreign_key: true
      t.references :assigned_by, foreign_key: { to_table: :users }
      t.references :assigned_to, null: false, foreign_key: { to_table: :users }
      t.datetime :created_at, null: false
    end

    add_index :conversation_assignments, [:conversation_id, :created_at]
  end
end
