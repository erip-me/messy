class CreateCsvImports < ActiveRecord::Migration[7.1]
  def change
    create_table :csv_imports do |t|
      t.references :account, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.text :csv_content
      t.jsonb :field_mapping, default: {}
      t.string :dedup_strategy, default: 'skip'
      t.string :status, default: 'pending'
      t.integer :total_rows, default: 0
      t.integer :processed_rows, default: 0
      t.integer :success_count, default: 0
      t.integer :failed_count, default: 0
      t.jsonb :row_errors, default: []
      t.timestamps
    end
    add_index :csv_imports, [:account_id, :status]
  end
end
