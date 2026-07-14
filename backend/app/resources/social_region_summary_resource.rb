# The compact region header used inside calendar/post payloads.
class SocialRegionSummaryResource
  include Alba::Resource

  attributes :id, :name, :timezone, :post_hour

  attribute :configured do |region|
    region.configured?
  end

  attribute :instagram_available do |region|
    region.instagram_available?
  end

  attribute :linkedin_available do |region|
    region.linkedin_available?
  end
end
