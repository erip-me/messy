class AddMessagesListingIndexes < ActiveRecord::Migration[8.0]
  # The transactional list view filters messages by environment (and account)
  # and orders by created_at desc. Single-column indexes force Postgres to sort
  # a large filtered set on every page. These composite indexes let it walk the
  # index in order and stop at the page boundary.
  def change
    add_index :messages, [:environment_id, :created_at],
              order: { created_at: :desc },
              name: "index_messages_on_environment_id_and_created_at",
              if_not_exists: true
    add_index :messages, [:account_id, :created_at],
              order: { created_at: :desc },
              name: "index_messages_on_account_id_and_created_at",
              if_not_exists: true
  end
end
