class AddLastSeenAtToCustomersAndCreateCustomerActivities < ActiveRecord::Migration[7.1]
  def change
    add_column :customers, :last_seen_at, :datetime

    create_table :customer_activities do |t|
      t.references :account, null: false, foreign_key: true
      t.references :customer, null: false, foreign_key: true
      t.references :environment, null: false, foreign_key: true
      t.string :activity_type, null: false, default: "identify"
      t.jsonb :properties, default: {}
      t.timestamps
    end

    add_index :customer_activities, [:account_id, :created_at]
  end
end
