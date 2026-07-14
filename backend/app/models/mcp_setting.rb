# Account-level MCP master switch. See CreateMcpSettings migration.
class McpSetting < ApplicationRecord
  belongs_to :account
end
