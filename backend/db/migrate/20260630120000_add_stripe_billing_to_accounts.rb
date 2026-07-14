class AddStripeBillingToAccounts < ActiveRecord::Migration[8.0]
  def change
    add_column :accounts, :stripe_customer_id, :string
    add_column :accounts, :stripe_subscription_id, :string
    add_column :accounts, :subscription_current_period_end, :datetime
    add_column :accounts, :subscription_cancel_at_period_end, :boolean, default: false, null: false

    add_index :accounts, :stripe_customer_id, unique: true
    add_index :accounts, :stripe_subscription_id, unique: true
  end
end
