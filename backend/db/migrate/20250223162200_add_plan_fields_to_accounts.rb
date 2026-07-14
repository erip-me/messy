class AddPlanFieldsToAccounts < ActiveRecord::Migration[7.1]
  def change
    add_column :accounts, :plan, :string, default: 'trial', null: false
    add_column :accounts, :trial_ends_at, :datetime
    add_column :accounts, :payment_status, :string
  end
end