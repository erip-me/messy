class CreateCampaignDeliveries < ActiveRecord::Migration[7.1]
  def change
    create_table :campaign_deliveries do |t|
      t.references :campaign, null: false, foreign_key: true
      t.references :account, null: false, foreign_key: true
      t.references :customer, null: true, foreign_key: true
      t.string :email, null: false
      t.string :status, default: 'pending'
      t.string :tracking_token, null: false
      t.datetime :sent_at
      t.datetime :opened_at
      t.integer :open_count, default: 0
      t.integer :click_count, default: 0
      t.text :error_message
      t.timestamps
    end
    add_index :campaign_deliveries, :tracking_token, unique: true
    add_index :campaign_deliveries, [:campaign_id, :status]
  end
end
