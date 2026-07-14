class CreatePageVisits < ActiveRecord::Migration[8.0]
  def change
    create_table :page_visits do |t|
      t.bigint :account_id, null: false
      t.bigint :customer_id
      t.string :visitor_token, null: false
      t.string :url, null: false
      t.string :title
      t.datetime :visited_at, null: false

      t.timestamps
    end

    add_index :page_visits, [:customer_id, :visited_at]
    add_index :page_visits, [:account_id, :visitor_token, :visited_at], name: "idx_page_visits_token_time"
    add_foreign_key :page_visits, :accounts
    add_foreign_key :page_visits, :customers
  end
end
