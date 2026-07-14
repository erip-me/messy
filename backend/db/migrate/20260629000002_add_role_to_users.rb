class AddRoleToUsers < ActiveRecord::Migration[8.0]
  def up
    # New invited users default to :member (0). Existing users predate the role
    # system and had full access, so backfill them to :admin (1) to avoid a
    # surprise lockout.
    add_column :users, :role, :integer, default: 0, null: false
    execute("UPDATE users SET role = 1")
  end

  def down
    remove_column :users, :role
  end
end
