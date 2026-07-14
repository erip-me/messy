class AddIntegrationPreferencesToEnvironments < ActiveRecord::Migration[8.0]
  def change
    add_reference :environments, :notification_email_integration, foreign_key: { to_table: :integrations }, null: true
    add_reference :environments, :campaign_email_integration, foreign_key: { to_table: :integrations }, null: true
  end
end
