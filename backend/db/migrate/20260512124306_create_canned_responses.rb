class CreateCannedResponses < ActiveRecord::Migration[8.0]
  def change
    create_table :canned_responses do |t|
      t.references :account, null: false, foreign_key: true
      t.string :shortcut, null: false
      t.string :title, null: false
      t.text :content, null: false
      t.references :created_by, foreign_key: { to_table: :users }
      t.timestamps
    end

    add_index :canned_responses, [:account_id, :shortcut], unique: true
  end
end
