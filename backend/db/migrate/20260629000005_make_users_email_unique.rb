class MakeUsersEmailUnique < ActiveRecord::Migration[8.0]
  def up
    # Email uniqueness was validation-only (racy under concurrent signups).
    # Promote the existing index to a unique constraint.
    remove_index :users, :email, name: "index_users_on_email"
    add_index :users, :email, unique: true, name: "index_users_on_email"
  end

  def down
    remove_index :users, :email, name: "index_users_on_email"
    add_index :users, :email, name: "index_users_on_email"
  end
end
