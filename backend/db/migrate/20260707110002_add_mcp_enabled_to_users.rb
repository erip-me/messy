# Per-user MCP gate. Disabling a user here kills every MCP connection they own
# without revoking each one individually. Defaults to true so existing users are
# eligible the moment an admin flips the account master switch on.
class AddMcpEnabledToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :mcp_enabled, :boolean, default: true, null: false
  end
end
