class AddMessageRetentionDaysToAccounts < ActiveRecord::Migration[8.0]
  def change
    add_column :accounts, :message_retention_days, :integer, default: 180, null: false
  end
end
