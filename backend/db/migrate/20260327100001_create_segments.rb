class CreateSegments < ActiveRecord::Migration[7.1]
  def change
    create_table :segments do |t|
      t.references :account, null: false, foreign_key: true
      t.string :name, null: false
      t.text :description
      t.jsonb :conditions, default: { "operator" => "and", "conditions" => [] }
      t.integer :customer_count, default: 0
      t.timestamps
    end
  end
end
