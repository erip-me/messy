# A calendar cell: enough to render the day without loading full alternatives.
class SocialPostSummaryResource
  include Alba::Resource

  attributes :id, :status, :post_hour, :effective_post_hour,
             :feed_alternative_id, :reel_alternative_id, :carousel_alternative_id

  attribute :date, &:post_date

  attribute :alternatives_count do |post|
    post.social_alternatives.size
  end

  attribute :thumb_url do |post|
    thumb = selected_thumb(post)
    thumb ? SocialMedia.thumb_url(thumb) : nil
  end

  attribute :thumb_content_type do |post|
    selected_thumb(post)&.blob&.content_type
  end

  attribute :thumbs do |post|
    alternative_thumbs(post)
  end

  attribute :has_video do |post|
    post.social_alternatives.any? { |a| media_video?(a.feed_media) || media_video?(a.reel_media) }
  end

  attribute :title do |post|
    summary_title(post)
  end

  attribute :posted_channels do |post|
    posted_channels(post)
  end

  attribute :past do |post|
    post.past?
  end

  # Headline that best represents a day in the calendar: the picked feed creative's
  # headline, else the first alternative that has one. nil when none is set.
  def summary_title(post)
    chosen = post.social_alternatives.detect { |a| a.id == post.feed_alternative_id } ||
             post.social_alternatives.detect { |a| a.headline.present? }
    chosen&.headline.presence
  end

  # Distinct channels this day was actually posted to (feeds the calendar's
  # "posted to" icons on a done day). Empty until something posts successfully.
  def posted_channels(post)
    post.social_post_deliveries.select { |d| d.status == "posted" }.map(&:channel).uniq
  end

  # One preview per alternative (prefer its feed creative, else the reel), so a
  # pending day can show all candidate creatives at a glance in the calendar cell.
  def alternative_thumbs(post)
    post.social_alternatives.filter_map do |a|
      media = a.feed_media.attached? ? a.feed_media : (a.reel_media.attached? ? a.reel_media : nil)
      next unless media

      { url: SocialMedia.thumb_url(media), content_type: media.blob.content_type }
    end
  end

  # Preview image for a calendar cell: prefer the picked feed creative (or reel),
  # otherwise fall back to any uploaded creative media so pending (not-yet-picked)
  # days still show a preview. nil only when the day has no media at all.
  def selected_thumb(post)
    feed = post.social_alternatives.detect { |a| a.id == post.feed_alternative_id }
    reel = post.social_alternatives.detect { |a| a.id == post.reel_alternative_id }
    candidates = [feed&.feed_media, reel&.reel_media, feed&.reel_media, reel&.feed_media]
    post.social_alternatives.each { |a| candidates.push(a.feed_media, a.reel_media) }
    candidates.find { |m| m&.attached? }
  end

  def media_video?(attachment)
    attachment.attached? && attachment.blob.content_type.to_s.start_with?("video/")
  end
end
