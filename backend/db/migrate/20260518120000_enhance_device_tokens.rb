class EnhanceDeviceTokens < ActiveRecord::Migration[8.0]
  def change
    add_column :device_tokens, :device_id, :string
    add_column :device_tokens, :app_id, :string
    add_column :device_tokens, :device_name, :string
    add_column :device_tokens, :last_used_at, :datetime

    add_index :device_tokens, [:account_id, :device_id], where: "device_id IS NOT NULL"
    add_index :device_tokens, [:account_id, :app_id], where: "app_id IS NOT NULL"
  end
end
