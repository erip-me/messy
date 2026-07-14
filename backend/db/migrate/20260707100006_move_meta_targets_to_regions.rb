# Move the publishing target (Page / Instagram / ad account) off the Meta
# integration and onto the region. The integration now holds only the shared
# credential (system-user token + app secret); each region targets one Page +
# IG under that token. Backfills existing regions from their linked account.
class MoveMetaTargetsToRegions < ActiveRecord::Migration[8.0]
  def up
    add_reference :social_regions, :integration, foreign_key: true, null: true
    add_column :social_regions, :page_id, :string
    add_column :social_regions, :page_name, :string
    add_column :social_regions, :ig_business_account_id, :string
    add_column :social_regions, :ig_username, :string
    add_column :social_regions, :ad_account_id, :string
    add_column :social_regions, :post_to_facebook, :boolean, null: false, default: true
    add_column :social_regions, :post_to_instagram, :boolean, null: false, default: true

    # Backfill each region from its first linked Meta account.
    execute <<~SQL
      UPDATE social_regions r
      SET integration_id        = sub.integration_id,
          page_id               = sub.page_id,
          ig_business_account_id = sub.ig_business_account_id,
          ad_account_id         = sub.ad_account_id
      FROM (
        SELECT DISTINCT ON (sc.social_region_id)
               sc.social_region_id,
               sc.integration_id,
               i.config->>'page_id'                AS page_id,
               i.config->>'ig_business_account_id' AS ig_business_account_id,
               i.config->>'ad_account_id'          AS ad_account_id
        FROM social_channels sc
        JOIN integrations i ON i.id = sc.integration_id
        ORDER BY sc.social_region_id, sc.id
      ) sub
      WHERE r.id = sub.social_region_id AND r.integration_id IS NULL
    SQL
  end

  def down
    remove_reference :social_regions, :integration, foreign_key: true
    remove_column :social_regions, :page_id
    remove_column :social_regions, :page_name
    remove_column :social_regions, :ig_business_account_id
    remove_column :social_regions, :ig_username
    remove_column :social_regions, :ad_account_id
    remove_column :social_regions, :post_to_facebook
    remove_column :social_regions, :post_to_instagram
  end
end
