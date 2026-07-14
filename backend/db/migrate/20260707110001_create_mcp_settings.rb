# Account-level master switch for the MCP server. One row per account; absence
# (or enabled: false) means the MCP endpoint rejects every tool call for the
# account. Kept in its own table rather than an accounts column so MCP config
# can grow (default scopes, allowed clients) without bloating accounts.
class CreateMcpSettings < ActiveRecord::Migration[8.0]
  def change
    create_table :mcp_settings do |t|
      t.bigint :account_id, null: false
      t.boolean :enabled, default: false, null: false
      t.timestamps
    end
    add_index :mcp_settings, :account_id, unique: true
    add_foreign_key :mcp_settings, :accounts, on_delete: :cascade
  end
end
