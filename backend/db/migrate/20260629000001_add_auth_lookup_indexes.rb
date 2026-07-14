class AddAuthLookupIndexes < ActiveRecord::Migration[8.0]
  def change
    # environments.api_key is looked up on every authenticated API request
    # (Environment.active.find_by(api_key:)). It had no index (seq-scan per
    # request) and no uniqueness guard.
    add_index :environments, :api_key, unique: true, name: "index_environments_on_api_key"

    # users.magic_link_token is looked up on every magic-link validation.
    add_index :users, :magic_link_token, name: "index_users_on_magic_link_token"
  end
end
