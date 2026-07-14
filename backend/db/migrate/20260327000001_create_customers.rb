class CreateCustomers < ActiveRecord::Migration[7.1]
  def change
    create_table :customers do |t|
      t.references :account, null: false, foreign_key: true
      t.string :email, null: false
      t.string :first_name
      t.string :last_name
      t.jsonb :custom_attributes, default: {}
      t.timestamps
    end
    add_index :customers, [:account_id, :email], unique: true
    add_index :customers, :email
  end
end
