# Short-lived, single-use OAuth authorization code. Stores only the SHA-256
# digest of the code plus the PKCE challenge and the redirect_uri it was bound to.
class McpAuthorizationCode < ApplicationRecord
  belongs_to :mcp_grant

  TTL = 5.minutes

  # Issues a code for a grant, returning the raw code (shown once, embedded in the
  # redirect back to the client).
  def self.issue!(grant:, redirect_uri:, code_challenge:, code_challenge_method: "S256")
    raw = SecureRandom.urlsafe_base64(32)
    create!(
      mcp_grant: grant,
      code_digest: McpToken.digest(raw),
      redirect_uri: redirect_uri,
      code_challenge: code_challenge,
      code_challenge_method: code_challenge_method,
      expires_at: TTL.from_now
    )
    raw
  end

  def self.find_valid(raw)
    return nil if raw.blank?
    code = find_by(code_digest: McpToken.digest(raw))
    return nil unless code && code.consumed_at.nil? && code.expires_at > Time.current
    code
  end

  def consume!
    update_column(:consumed_at, Time.current)
  end
end
