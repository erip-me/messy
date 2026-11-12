class AddLastLoginIndexToUsers < ActiveRecord::Migration[8.0]
  def change
    # The Pushleft App admin user list is ordered by last sign-in, newest first,
    # and is polled while someone watches it.
    add_index :users, [:last_login_at, :id],
              order: { last_login_at: "DESC NULLS LAST", id: :desc },
              name: "index_users_on_last_login_at_and_id"
  end
end
