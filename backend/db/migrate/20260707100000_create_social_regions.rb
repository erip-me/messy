# A market a social content-calendar is organised around (e.g. Pakistan, Vietnam).
# Account-scoped like the rest of Messy (optionally environment-scoped). A region
# carries its posting timezone + daily post hour + ad-targeting countries, and
# links to one or more social accounts (Meta integrations) via social_channels.
class CreateSocialRegions < ActiveRecord::Migration[8.0]
  def change
    create_table :social_regions do |t|
      t.references :account, null: false, foreign_key: true
      t.references :environment, foreign_key: true # optional workspace scope
      t.string  :name, null: false
      t.string  :timezone, null: false, default: "UTC" # IANA tz — posts at local time
      t.integer :post_hour, null: false, default: 9    # 0-23, region-local publish hour
      t.jsonb   :countries, null: false, default: []    # ISO codes for ad targeting
      t.boolean :active, null: false, default: true
      t.timestamps
    end

    add_index :social_regions, %i[account_id name]
  end
end
