# OAuth 2.1 clients created via Dynamic Client Registration (RFC 7591). These are
# the MCP apps (Claude, OpenAI, MCP Inspector, ...) that connect. They are global,
# not account-scoped: a client registers before any user has authenticated, and
# tenant identity is bound later at consent time on the McpGrant. Public PKCE
# clients have no secret (client_secret_digest is null).
class CreateMcpClients < ActiveRecord::Migration[8.0]
  def change
    create_table :mcp_clients do |t|
      t.string :client_id, null: false
      t.string :client_secret_digest
      t.string :name
      t.jsonb :redirect_uris, default: [], null: false
      t.jsonb :grant_types, default: %w[authorization_code refresh_token], null: false
      t.string :token_endpoint_auth_method, default: "none", null: false
      t.timestamps
    end
    add_index :mcp_clients, :client_id, unique: true
  end
end
