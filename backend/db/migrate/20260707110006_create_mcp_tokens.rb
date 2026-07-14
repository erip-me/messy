# Issued bearer credentials. kind 0 = access (~1h TTL), 1 = refresh (long-lived,
# rotated on every use). Only the SHA-256 digest is stored; the raw token is
# returned once from /oauth/token and never persisted. Revoked when the parent
# grant is revoked or on refresh rotation.
class CreateMcpTokens < ActiveRecord::Migration[8.0]
  def change
    create_table :mcp_tokens do |t|
      t.bigint :mcp_grant_id, null: false
      t.integer :kind, default: 0, null: false
      t.string :token_digest, null: false
      t.datetime :expires_at
      t.datetime :revoked_at
      t.datetime :last_used_at
      t.timestamps
    end
    add_index :mcp_tokens, :token_digest, unique: true
    add_index :mcp_tokens, [:mcp_grant_id, :kind]
    add_foreign_key :mcp_tokens, :mcp_grants, on_delete: :cascade
  end
end
