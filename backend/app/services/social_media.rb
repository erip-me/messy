# Resolves publicly-fetchable URLs for a Social attachment, both for handing to
# the Meta Graph API (which fetches the media by URL) and for the admin UI. Uses
# Active Storage *proxy* URLs rather than redirect URLs: proxy responses are
# served with `Cache-Control: public, immutable`, so the browser and Cloudflare
# cache them — a backend redeploy no longer blanks already-loaded images. URLs
# resolve against default_url_options[:host].
module SocialMedia
  module_function

  def video?(attachment)
    attachment.attached? && attachment.blob.content_type.to_s.start_with?("video/")
  end

  def public_url(attachment)
    Rails.application.routes.url_helpers.rails_storage_proxy_url(attachment)
  end

  # A small preview URL for calendar/list cells. Originals average ~0.7MB and a
  # month grid loads dozens of them, so images get a resized variant (processed
  # lazily on first request, then cached by the browser + Cloudflare). Videos
  # have no cheap preview without ffmpeg, so they fall through to the original.
  def thumb_url(attachment)
    return public_url(attachment) unless attachment.blob.image?

    Rails.application.routes.url_helpers.rails_storage_proxy_url(attachment.variant(resize_to_limit: [320, 320]))
  end

  # A public JPEG URL. Instagram's image API only accepts JPEG, so non-JPEG
  # attachments are converted to a stored JPEG variant first.
  def jpeg_url(attachment)
    return public_url(attachment) if attachment.blob.content_type == "image/jpeg"

    variant = attachment.variant(format: :jpeg).processed
    Rails.application.routes.url_helpers.rails_storage_proxy_url(variant)
  end
end
