# Audit trail for the MCP management UI: one row per tools/call (and per rejected
# attempt). status 0 = ok, 1 = error (tool ran, non-2xx), 2 = rejected (gate/auth
# blocked it before dispatch). arguments is parameter-filtered before insert.
class CreateMcpRequestLogs < ActiveRecord::Migration[8.0]
  def change
    create_table :mcp_request_logs do |t|
      t.bigint :account_id, null: false
      t.bigint :mcp_grant_id
      t.bigint :user_id
      t.bigint :environment_id
      t.string :tool_name
      t.string :jsonrpc_method
      t.jsonb :arguments, default: {}, null: false
      t.integer :status, default: 0, null: false
      t.integer :http_status
      t.integer :duration_ms
      t.string :error_message
      t.datetime :created_at, null: false
    end
    add_index :mcp_request_logs, [:account_id, :created_at]
    add_index :mcp_request_logs, :mcp_grant_id
    add_foreign_key :mcp_request_logs, :accounts, on_delete: :cascade
    add_foreign_key :mcp_request_logs, :mcp_grants, on_delete: :nullify
  end
end
