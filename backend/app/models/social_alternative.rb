# A creative variant within a day: editable copy plus a 4:5 feed render and a
# 9:16 reel render (each an image or a video). Any variant can be drafted into
# Meta Ads Manager as its own PAUSED lead-gen ad; the Meta ids live here.
class SocialAlternative < ApplicationRecord
  belongs_to :social_post

  has_one_attached :feed_media # 4:5 feed render
  has_one_attached :reel_media # 9:16 reel render (more conversion-oriented)
  has_many_attached :carousel_media # ordered image set for a native carousel post

  enum :source, { generated: 0, manual: 1 }

  scope :ordered, -> { order(position: :asc, created_at: :asc) }

  # Clear this variant from the post's slots before it's removed so a
  # selected-but-deleted variant never dangles (the SET NULL FK is the backstop).
  before_destroy :clear_post_selection

  def drafted?
    meta_ad_id.present?
  end

  # The attachment for a given slot ("feed"/"reel"); defaults to feed, falls back
  # to reel. Returns nil if neither is attached. (Carousel is multi-media — use
  # carousel_images / has_slot_media?.)
  def media_for(slot = nil)
    case slot.to_s
    when "reel" then reel_media if reel_media.attached?
    when "feed" then feed_media if feed_media.attached?
    else feed_media.attached? ? feed_media : (reel_media if reel_media.attached?)
    end
  end

  CAROUSEL_MIN = 2
  CAROUSEL_MAX = 10 # Instagram caps carousels at 10 items.

  # Carousels are images only; the ordered image renders, capped at the platform
  # maximum so a native carousel post is never rejected.
  def carousel_images
    carousel_media.select { |m| m.blob.content_type.to_s.start_with?("image/") }.first(CAROUSEL_MAX)
  end

  # Whether this variant has media to fill a given slot (feed/reel single asset,
  # carousel needs at least two images).
  def has_slot_media?(slot)
    slot.to_s == "carousel" ? carousel_images.size >= CAROUSEL_MIN : media_for(slot).present?
  end

  # Caption for an organic post: headline + body + CTA label, blanks dropped.
  # Hashtags are chosen from the region's pool and baked into the body at
  # generation time, so nothing is appended automatically here.
  def caption
    [headline, body, cta_label].map { |s| s.to_s.strip }.reject(&:blank?).join("\n\n")
  end

  # The image used when drafting a Meta ad — prefer the 9:16 reel, else the feed.
  # Meta ad images must be images (not video), so skip any video asset.
  def ad_image_attachment
    [reel_media, feed_media].find do |m|
      m.attached? && m.blob.content_type.to_s.start_with?("image/")
    end
  end

  private

  def clear_post_selection
    updates = {}
    updates[:feed_alternative_id] = nil if social_post.feed_alternative_id == id
    updates[:reel_alternative_id] = nil if social_post.reel_alternative_id == id
    updates[:carousel_alternative_id] = nil if social_post.carousel_alternative_id == id
    social_post.update_columns(updates) if updates.any?
  end
end
