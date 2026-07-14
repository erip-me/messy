# An issued bearer credential (access or refresh). Only the digest is stored; the
# raw token is returned once from /oauth/token. This model owns the canonical
# SHA-256 digest helper reused by the authorization-code and client-secret models.
class McpToken < ApplicationRecord
  belongs_to :mcp_grant

  enum :kind, { access: 0, refresh: 1 }

  ACCESS_TTL  = 1.hour
  REFRESH_TTL = 30.days

  scope :active, -> { where(revoked_at: nil) }

  def self.digest(raw)
    Digest::SHA256.hexdigest(raw.to_s)
  end

  # Issues a token of the given kind, returning [record, raw_token].
  def self.issue!(grant:, kind:)
    raw = "mcp_#{kind}_#{SecureRandom.urlsafe_base64(32)}"
    ttl = kind.to_sym == :refresh ? REFRESH_TTL : ACCESS_TTL
    record = create!(
      mcp_grant: grant,
      kind: kind,
      token_digest: digest(raw),
      expires_at: ttl.from_now
    )
    [record, raw]
  end

  # Resolves a raw bearer token to a live token record of the given kind.
  def self.authenticate(raw, kind:)
    return nil if raw.blank?
    token = find_by(token_digest: digest(raw), kind: kinds[kind])
    return nil unless token&.live?
    token
  end

  def live?
    revoked_at.nil? && (expires_at.nil? || expires_at > Time.current)
  end

  def revoke!
    update_column(:revoked_at, Time.current)
  end

  def touch_used!
    update_column(:last_used_at, Time.current)
  end
end
