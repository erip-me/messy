class SocialAlternativeResource
  include Alba::Resource

  attributes :id, :headline, :body, :cta_label, :cta_url, :source

  attribute :feed_media_url do |alt|
    alt.feed_media.attached? ? SocialMedia.public_url(alt.feed_media) : nil
  end

  attribute :feed_content_type do |alt|
    alt.feed_media.attached? ? alt.feed_media.blob.content_type : nil
  end

  attribute :reel_media_url do |alt|
    alt.reel_media.attached? ? SocialMedia.public_url(alt.reel_media) : nil
  end

  attribute :reel_content_type do |alt|
    alt.reel_media.attached? ? alt.reel_media.blob.content_type : nil
  end

  attribute :carousel_media do |alt|
    alt.carousel_media.map { |m| { url: SocialMedia.public_url(m), content_type: m.blob.content_type } }
  end
end
