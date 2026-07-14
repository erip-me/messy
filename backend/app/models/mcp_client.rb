# A registered OAuth client (an MCP app such as Claude or OpenAI). Created via
# Dynamic Client Registration. Public PKCE clients (token_endpoint_auth_method
# "none") have no secret; confidential clients store only the secret digest.
class McpClient < ApplicationRecord
  has_many :mcp_grants, dependent: :destroy

  before_validation :assign_client_id, on: :create

  validates :client_id, presence: true, uniqueness: true

  # Registers a client and, for confidential clients, returns the one-time raw
  # secret alongside the record so the caller can hand it back in the DCR response.
  def self.register!(name:, redirect_uris:, token_endpoint_auth_method: "none", grant_types: %w[authorization_code refresh_token])
    secret = nil
    client = new(
      name: name.presence || "MCP client",
      redirect_uris: Array(redirect_uris),
      token_endpoint_auth_method: token_endpoint_auth_method,
      grant_types: grant_types
    )
    if token_endpoint_auth_method != "none"
      secret = SecureRandom.urlsafe_base64(32)
      client.client_secret_digest = McpToken.digest(secret)
    end
    client.save!
    [client, secret]
  end

  def redirect_uri_allowed?(uri)
    redirect_uris.include?(uri)
  end

  def secret_matches?(raw)
    return true if token_endpoint_auth_method == "none" && client_secret_digest.blank?
    return false if raw.blank? || client_secret_digest.blank?
    ActiveSupport::SecurityUtils.secure_compare(client_secret_digest, McpToken.digest(raw))
  end

  private

  def assign_client_id
    self.client_id ||= "mcp_client_#{SecureRandom.hex(16)}"
  end
end
