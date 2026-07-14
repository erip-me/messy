# Fans a day's selected creatives out to its region's Meta target — the Page
# (Facebook) and, when set, the linked Instagram account — using the region's
# credential (token) integration, and logs each attempt as a SocialPostDelivery.
# Two entry points:
#
#   publish_post(post)               — the day's feed/reel selections to the
#                                      region's default channels; idempotent (a
#                                      target already posted is skipped) and
#                                      updates post status.
#   publish_alternative_now(post, alt, slot) — ad-hoc "post now" of one creative;
#                                      not idempotent, leaves the day's
#                                      selection/status untouched.
class SocialPublisher
  def self.publish_post(post)
    new.publish_post(post)
  end

  # Publish the day's selected slots to the region's default channels.
  def publish_post(post)
    region = post.social_region
    return post unless region.configured?

    post.selected_slots.each do |slot, alt|
      next unless alt&.has_slot_media?(slot)

      publish_slot(post, region, alt, slot, idempotent: true, channels: region.enabled_channels)
    end
    finalize_post_status(post)
    post
  end

  # Ad-hoc publish of one creative's slot. `channels` (an array like
  # %w[facebook instagram]) is the operator's explicit pick; nil falls back to the
  # region's default channels.
  def publish_alternative_now(post, alt, slot, channels: nil)
    region = post.social_region
    return [] unless alt.has_slot_media?(slot) && region.configured?

    targets = channels ? (channels.map(&:to_s) & region.available_channels) : region.enabled_channels
    publish_slot(post, region, alt, slot, idempotent: false, channels: targets)
  end

  private

  # Publish one (alternative, slot) to the region's target, limited to the given
  # channels (Instagram only when the region has one). Returns the delivery rows.
  def publish_slot(post, region, alt, slot, idempotent:, channels:)
    return publish_carousel(post, region, alt, idempotent: idempotent, channels: channels) if slot.to_s == "carousel"

    media = alt.media_for(slot)
    return [] unless media

    meta = region.token_integration
    video = SocialMedia.video?(media)
    rows = []

    if channels.include?("facebook")
      rows << deliver(post, meta, slot, :facebook, idempotent) do
        meta.publish_facebook(page_id: region.page_id, media_url: SocialMedia.public_url(media), caption: alt.caption, video: video)
      end
    end

    if channels.include?("instagram") && region.instagram_available?
      rows << deliver(post, meta, slot, :instagram, idempotent) do
        url = video ? SocialMedia.public_url(media) : SocialMedia.jpeg_url(media)
        meta.publish_instagram(ig_user_id: region.ig_business_account_id, page_id: region.ig_publish_page_id,
                               media_url: url, caption: alt.caption, video: video)
      end
    end

    # LinkedIn ingests the image bytes and (this pass) publishes images only, so
    # a video feed/reel slot is skipped for LinkedIn rather than posted. The same
    # predicate gates required_targets, so publish and status stay in lock-step.
    if channels.include?("linkedin") && region.linkedin_configured? && linkedin_slot_ok?(alt, slot)
      li = region.linkedin_token_integration
      rows << deliver(post, li, slot, :linkedin, idempotent) do
        li.publish_organization_post(org_id: region.linkedin_org_id, images: [linkedin_image(media)], caption: alt.caption)
      end
    end

    rows.compact
  end

  # Publish the alternative's ordered carousel images as a native FB multi-photo
  # post and an IG carousel.
  def publish_carousel(post, region, alt, idempotent:, channels:)
    images = alt.carousel_images
    return [] if images.size < 2

    meta = region.token_integration
    rows = []

    if channels.include?("facebook")
      rows << deliver(post, meta, :carousel, :facebook, idempotent) do
        meta.publish_facebook_carousel(page_id: region.page_id,
                                       media_urls: images.map { |m| SocialMedia.public_url(m) }, caption: alt.caption)
      end
    end

    if channels.include?("instagram") && region.instagram_available?
      rows << deliver(post, meta, :carousel, :instagram, idempotent) do
        meta.publish_instagram_carousel(ig_user_id: region.ig_business_account_id, page_id: region.ig_publish_page_id,
                                        media_urls: images.map { |m| SocialMedia.jpeg_url(m) }, caption: alt.caption)
      end
    end

    if channels.include?("linkedin") && region.linkedin_configured?
      li = region.linkedin_token_integration
      rows << deliver(post, li, :carousel, :linkedin, idempotent) do
        li.publish_organization_post(org_id: region.linkedin_org_id,
                                     images: images.map { |m| linkedin_image(m) }, caption: alt.caption)
      end
    end

    rows.compact
  end

  # LinkedIn's Images API ingests the raw bytes (it doesn't fetch by URL like
  # Meta), so hand it the attachment's downloaded content + type.
  def linkedin_image(attachment)
    { data: attachment.download, content_type: attachment.blob.content_type }
  end

  # Create + run one delivery. Skips (returns nil) when idempotent and the target
  # is already posted. Records the provider id on success, the error on failure —
  # a channel failure never raises out of here.
  def deliver(post, integ, slot, channel, idempotent)
    return nil if idempotent && SocialPostDelivery.posted_target?(post.id, integ.id, slot, channel)

    delivery = SocialPostDelivery.create!(
      social_post: post, integration: integ, account_id: post.account_id,
      slot: slot, channel: channel, status: :pending
    )
    begin
      delivery.update!(status: :posted, provider_post_id: yield, posted_at: Time.current)
    rescue StandardError => e
      delivery.update!(status: :failed, error_message: e.message)
    end
    delivery
  end

  # posted when every required (account, slot, channel) target has a posted
  # delivery; otherwise failed with the recent errors.
  def finalize_post_status(post)
    targets = required_targets(post)
    if targets.empty?
      # No selection → genuinely nothing to do, leave the status untouched.
      return if post.selected_slots.empty?

      # Selected, but nothing is publishable (e.g. a video slot on a LinkedIn-only
      # region, or every channel toggled off). Surface it and stop the scheduler
      # from re-enqueuing a silent no-op every sweep.
      post.update!(status: :failed,
                   publish_error: "Nothing could be published: no enabled channel accepts the selected creative")
      return
    end

    all_posted = targets.all? { |iid, slot, ch| SocialPostDelivery.posted_target?(post.id, iid, slot, ch) }
    if all_posted
      post.update!(status: :posted, publish_error: nil)
    else
      errs = post.social_post_deliveries.where(status: :failed).recent.limit(5).pluck(:error_message).compact.uniq
      post.update!(status: :failed, publish_error: errs.join(" | ").presence)
    end
  end

  def required_targets(post)
    region = post.social_region
    return [] unless region.configured?

    post.selected_slots.flat_map do |slot, alt|
      next [] unless alt&.has_slot_media?(slot)

      region.enabled_channels.filter_map do |channel|
        next if channel == "linkedin" && !linkedin_slot_ok?(alt, slot)

        integ = integration_for(region, channel)
        integ && [integ.id, slot, channel]
      end
    end
  end

  # The credential a given channel publishes through — LinkedIn has its own,
  # Facebook/Instagram share the Meta one.
  def integration_for(region, channel)
    channel.to_s == "linkedin" ? region.linkedin_token_integration : region.token_integration
  end

  # LinkedIn publishes images only this pass; a video feed/reel slot isn't a
  # LinkedIn target (carousels are always images), so it must not be "required"
  # or the post could never reach "posted".
  def linkedin_slot_ok?(alt, slot)
    return true if slot.to_s == "carousel"

    media = alt.media_for(slot)
    media && !SocialMedia.video?(media)
  end
end
