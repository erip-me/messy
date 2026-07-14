class AddUniqueConstraintToCustomerAnonymousToken < ActiveRecord::Migration[8.0]
  def up
    # Remove duplicates: keep the oldest customer per account+token, delete newer duplicates
    execute <<~SQL
      DELETE FROM customers
      WHERE id NOT IN (
        SELECT MIN(id)
        FROM customers
        WHERE anonymous_token IS NOT NULL
        GROUP BY account_id, anonymous_token
      )
      AND anonymous_token IS NOT NULL
    SQL

    # Replace non-unique index with unique one
    remove_index :customers, name: "idx_customers_anonymous_token"
    add_index :customers, [:account_id, :anonymous_token],
              unique: true,
              where: "anonymous_token IS NOT NULL",
              name: "idx_customers_anonymous_token_unique"
  end

  def down
    remove_index :customers, name: "idx_customers_anonymous_token_unique"
    add_index :customers, [:account_id, :anonymous_token],
              where: "(anonymous_token IS NOT NULL)",
              name: "idx_customers_anonymous_token"
  end
end
