class AddCampaignEnhancements < ActiveRecord::Migration[8.0]
  def change
    add_column :campaigns, :channel, :string, default: 'email', null: false
    add_column :campaigns, :template_id, :bigint
    add_column :campaigns, :environment_id, :bigint
    add_foreign_key :campaigns, :templates
    add_foreign_key :campaigns, :environments
    add_index :campaigns, :environment_id
    add_index :campaigns, :template_id

    add_column :campaign_deliveries, :channel, :string, default: 'email'
    add_column :customers, :unsubscribed_channels, :jsonb, default: {}
  end
end
