class AddOnboardingAndStatus < ActiveRecord::Migration[7.1]
  def change
    add_column :accounts, :status, :string, default: 'pending_verification', null: false
    add_column :accounts, :onboarding_completed_at, :datetime
    add_column :accounts, :onboarding_step, :integer, default: 0, null: false
    add_column :users, :email_verified, :boolean, default: false, null: false

    # Existing accounts are already active and fully onboarded
    reversible do |dir|
      dir.up do
        Account.update_all(status: 'active', onboarding_step: 2, onboarding_completed_at: Time.current)
        User.update_all(email_verified: true)
      end
    end
  end
end
