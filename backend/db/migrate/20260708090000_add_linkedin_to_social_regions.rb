class AddLinkedinToSocialRegions < ActiveRecord::Migration[8.0]
  def change
    add_column :social_regions, :linkedin_integration_id, :bigint
    add_column :social_regions, :linkedin_org_id, :string
    add_column :social_regions, :linkedin_org_name, :string
    add_column :social_regions, :post_to_linkedin, :boolean, default: true, null: false
    add_index  :social_regions, :linkedin_integration_id
  end
end
