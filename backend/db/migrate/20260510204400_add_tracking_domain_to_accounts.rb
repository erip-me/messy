class AddTrackingDomainToAccounts < ActiveRecord::Migration[8.0]
  def change
    add_column :accounts, :tracking_domain, :string
  end
end
