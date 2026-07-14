# Signs/verifies the destination URL embedded in click-tracking links so the
# redirect endpoint will only forward to URLs we generated. Without this, the
# `url` param is attacker-controlled and the endpoint is an open redirect.
#
# The `purpose` namespaces a signature to one kind of link (e.g. campaign vs
# transactional), so a signature minted for one context can't be replayed in
# another. See CampaignLinkSigner and Message::CLICK_SIGNATURE_PURPOSE.
module TrackingLinkSigner
  def tracking_link_signature(url, purpose)
    OpenSSL::HMAC.hexdigest(
      "SHA256",
      Rails.application.secret_key_base,
      "#{purpose}:#{url}"
    )
  end

  def valid_tracking_link?(url, signature, purpose)
    return false if url.blank? || signature.blank?

    ActiveSupport::SecurityUtils.secure_compare(
      tracking_link_signature(url, purpose), signature
    )
  end
end
