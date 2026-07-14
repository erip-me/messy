class AddTrackingToMessages < ActiveRecord::Migration[7.0]
  def change
    add_column :messages, :tracking_token, :string, null: true, index: true
    add_column :messages, :tracking_salt, :string, null: true
    add_column :messages, :open_count, :integer, default: 0, null: false
    add_column :messages, :first_opened_at, :datetime, null: true
    
    add_index :messages, :tracking_token, unique: true
  end
end