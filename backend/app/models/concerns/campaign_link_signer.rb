# Signs/verifies the destination URL embedded in campaign click-tracking links.
# Thin wrapper over the shared TrackingLinkSigner, pinned to the "campaign_click"
# purpose so signatures stay namespaced to campaigns (and links already sent keep
# verifying). Transactional click tracking uses Message::CLICK_SIGNATURE_PURPOSE.
module CampaignLinkSigner
  include TrackingLinkSigner

  SIGNATURE_PURPOSE = "campaign_click".freeze

  def campaign_link_signature(url)
    tracking_link_signature(url, SIGNATURE_PURPOSE)
  end

  def valid_campaign_link?(url, signature)
    valid_tracking_link?(url, signature, SIGNATURE_PURPOSE)
  end
end
