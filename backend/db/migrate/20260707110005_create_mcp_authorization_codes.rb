# Short-lived (5 min), single-use OAuth authorization codes. Only the SHA-256
# digest of the code is stored. Carries the PKCE challenge so /oauth/token can
# verify the code_verifier, plus the exact redirect_uri it was issued for. The
# grant is created at consent time and referenced here; consuming the code mints
# the tokens.
class CreateMcpAuthorizationCodes < ActiveRecord::Migration[8.0]
  def change
    create_table :mcp_authorization_codes do |t|
      t.string :code_digest, null: false
      t.bigint :mcp_grant_id, null: false
      t.string :redirect_uri, null: false
      t.string :code_challenge, null: false
      t.string :code_challenge_method, default: "S256", null: false
      t.datetime :expires_at, null: false
      t.datetime :consumed_at
      t.timestamps
    end
    add_index :mcp_authorization_codes, :code_digest, unique: true
    add_index :mcp_authorization_codes, :mcp_grant_id
    add_foreign_key :mcp_authorization_codes, :mcp_grants, on_delete: :cascade
  end
end
