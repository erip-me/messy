# A connection: a user's consent for one MCP client to act on one environment of
# their account. Access/refresh tokens hang off it. `enabled?` re-checks all three
# gates (account master, per-user, per-connection) and is consulted on every
# tools/call — not just at connect time.
class McpGrant < ApplicationRecord
  belongs_to :account
  belongs_to :user
  belongs_to :environment
  belongs_to :mcp_client
  has_many :mcp_tokens, dependent: :destroy
  has_many :mcp_authorization_codes, dependent: :destroy
  has_many :mcp_request_logs, dependent: :nullify

  scope :active, -> { where(revoked_at: nil) }

  def revoked?
    revoked_at.present?
  end

  # Every gate that can block this connection, evaluated fresh each call.
  def enabled?
    !revoked? && user.mcp_enabled && account.mcp_enabled?
  end

  def revoke!
    update!(revoked_at: Time.current)
    mcp_tokens.active.update_all(revoked_at: Time.current)
  end

  def touch_used!
    update_column(:last_used_at, Time.current)
  end
end
