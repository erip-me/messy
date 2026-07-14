# A full day: region header plus every alternative with media URLs.
class SocialPostDetailResource
  include Alba::Resource

  attributes :id, :status, :post_hour, :effective_post_hour,
             :feed_alternative_id, :reel_alternative_id, :carousel_alternative_id,
             :publish_error

  attribute :region do |post|
    SocialRegionSummaryResource.new(post.social_region).to_h
  end

  attribute :date, &:post_date

  attribute :past do |post|
    post.past?
  end

  attribute :postable_today do |post|
    post.postable_today?
  end

  attribute :alternatives do |post|
    SocialAlternativeResource.new(post.social_alternatives.ordered).to_h
  end
end
