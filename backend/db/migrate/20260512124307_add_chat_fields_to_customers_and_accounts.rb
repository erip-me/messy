class AddChatFieldsToCustomersAndAccounts < ActiveRecord::Migration[8.0]
  def change
    # Customer fields for anonymous visitor tracking
    change_column_null :customers, :email, true
    add_column :customers, :anonymous_token, :string
    add_column :customers, :phone, :string
    add_column :customers, :browser, :string
    add_column :customers, :os, :string
    add_column :customers, :country, :string
    add_column :customers, :city, :string
    add_column :customers, :current_page_url, :string
    add_column :customers, :current_page_title, :string
    add_column :customers, :online, :boolean, default: false

    add_index :customers, [:account_id, :anonymous_token],
              where: "anonymous_token IS NOT NULL",
              name: "idx_customers_anonymous_token"

    # Account chat toggle
    add_column :accounts, :chat_enabled, :boolean, default: false
  end
end
