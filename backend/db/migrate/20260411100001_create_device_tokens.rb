class CreateDeviceTokens < ActiveRecord::Migration[7.1]
  def change
    create_table :device_tokens do |t|
      t.references :account, null: false, foreign_key: true
      t.references :customer, null: false, foreign_key: true
      t.string :token, null: false
      t.integer :platform, null: false
      t.boolean :active, default: true, null: false
      t.timestamps
    end

    add_index :device_tokens, :token, unique: true
    add_index :device_tokens, [:customer_id, :active]
  end
end
