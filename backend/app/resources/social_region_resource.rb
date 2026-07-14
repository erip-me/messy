# Full region settings view (regions management page).
class SocialRegionResource
  include Alba::Resource

  attributes :id, :name, :timezone, :post_hour, :countries, :hashtags, :active,
             :integration_id, :page_id, :page_name,
             :ig_business_account_id, :ig_username, :ig_page_id, :ad_account_id,
             :linkedin_integration_id, :linkedin_org_id, :linkedin_org_name,
             :post_to_facebook, :post_to_instagram, :post_to_linkedin

  attribute :configured do |region|
    region.configured?
  end

  attribute :instagram_available do |region|
    region.instagram_available?
  end

  attribute :linkedin_available do |region|
    region.linkedin_available?
  end

  attribute :integration_label do |region|
    integ = region.token_integration
    integ&.label.presence || integ&.name
  end

  attribute :linkedin_integration_label do |region|
    li = region.linkedin_token_integration
    li&.label.presence || li&.name
  end
end
