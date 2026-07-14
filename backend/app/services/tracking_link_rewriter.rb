# Wraps each <a href> in an HTML body in a signed click-tracking redirect through
# a tracking domain. Shared by transactional sends (Message) and campaign sends
# (SendCampaignDeliveryJob), which differ only in the URL path segment, the
# signature purpose, and whether some links are left untouched.
#
#   base  — tracking base URL (no trailing slash), e.g. https://track.example.com
#   token — per-message/delivery tracking token embedded in the redirect path
#   path  — path segment before the token: "track" or "campaign_track"
#   sign  — proc.(url) => HMAC signature string for that URL
#   skip  — optional proc.(url) => true to leave a link untouched (e.g. non-http
#           or self-referential links). When omitted, every <a href> is rewritten.
module TrackingLinkRewriter
  module_function

  def call(html, base:, token:, path:, sign:, skip: nil)
    html.gsub(/<a\s+([^>]*?)href=["']([^"']+)["']([^>]*)>/i) do
      before_attrs = $1
      original_url = $2
      after_attrs  = $3

      next $~[0] if skip&.call(original_url)

      signature   = sign.call(original_url)
      tracked_url = "#{base}/#{path}/#{token}/click?url=#{CGI.escape(original_url)}&sig=#{signature}"
      %(<a #{before_attrs}href="#{tracked_url}"#{after_attrs}>)
    end
  end
end
