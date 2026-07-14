# A "connection": the record created when a user consents to let an MCP client
# access one environment of their account. This is the unit the management UI
# lists and revokes. Access/refresh tokens hang off it (mcp_tokens); revoking the
# grant (or disabling the user/account above it) invalidates them all.
class CreateMcpGrants < ActiveRecord::Migration[8.0]
  def change
    create_table :mcp_grants do |t|
      t.bigint :account_id, null: false
      t.bigint :user_id, null: false
      t.bigint :environment_id, null: false
      t.bigint :mcp_client_id, null: false
      t.jsonb :scopes, default: [], null: false
      t.datetime :revoked_at
      t.datetime :last_used_at
      t.timestamps
    end
    add_index :mcp_grants, :account_id
    add_index :mcp_grants, :user_id
    add_index :mcp_grants, [:user_id, :mcp_client_id, :environment_id]
    add_foreign_key :mcp_grants, :accounts, on_delete: :cascade
    add_foreign_key :mcp_grants, :users, on_delete: :cascade
    add_foreign_key :mcp_grants, :environments, on_delete: :cascade
    add_foreign_key :mcp_grants, :mcp_clients, on_delete: :cascade
  end
end
