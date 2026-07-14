class MaglickAddToUsers < ActiveRecord::Migration[7.1]
  def change
    add_column :users, :magic_link_token, :string
    add_column :users, :magic_link_token_expires_at, :datetime
  end
end
