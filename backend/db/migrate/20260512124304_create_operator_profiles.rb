class CreateOperatorProfiles < ActiveRecord::Migration[8.0]
  def change
    create_table :operator_profiles do |t|
      t.references :user, null: false, foreign_key: true, index: { unique: true }
      t.references :account, null: false, foreign_key: true
      t.string :public_name, null: false
      t.text :bio
      t.integer :availability, null: false, default: 0
      t.boolean :auto_assign, default: true
      t.integer :max_concurrent_chats, default: 10
      t.datetime :last_heartbeat_at
      t.timestamps
    end

    add_index :operator_profiles, [:account_id, :availability]
  end
end
