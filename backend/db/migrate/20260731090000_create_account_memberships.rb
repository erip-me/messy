class CreateAccountMemberships < ActiveRecord::Migration[8.0]
  # A user may belong to several accounts ("workspaces" in the UI). Membership —
  # and the per-workspace role — moves out of users.account_id / users.role into
  # this join table.
  #
  # users.account_id is intentionally KEPT as the default/last-used workspace
  # pointer: it gives magic-link login somewhere to land before a workspace is
  # chosen, and keeps the backfill reversible. users.role is likewise kept for
  # one release so a rollback doesn't lose role data.
  def up
    create_table :account_memberships do |t|
      t.references :user, null: false, foreign_key: true
      t.references :account, null: false, foreign_key: true
      t.integer :role, null: false, default: 0

      t.timestamps
    end

    add_index :account_memberships, %i[user_id account_id], unique: true,
              name: "index_account_memberships_on_user_and_account"

    # Backfill one membership per existing user, carrying the role across.
    execute <<~SQL
      INSERT INTO account_memberships (user_id, account_id, role, created_at, updated_at)
      SELECT id, account_id, role, NOW(), NOW()
      FROM users
      WHERE account_id IS NOT NULL
    SQL
  end

  def down
    drop_table :account_memberships
  end
end
