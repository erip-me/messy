# One row per MCP tools/call (and per rejected attempt) for the management UI's
# usage log. See CreateMcpRequestLogs migration for the status enum semantics.
class McpRequestLog < ApplicationRecord
  belongs_to :account
  belongs_to :mcp_grant, optional: true
  belongs_to :user, optional: true
  belongs_to :environment, optional: true

  enum :status, { ok: 0, error: 1, rejected: 2 }
  # No updated_at column: log rows are immutable. Rails auto-sets created_at and
  # simply skips the absent updated_at.
end
