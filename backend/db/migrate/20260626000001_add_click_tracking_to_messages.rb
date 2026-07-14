class AddClickTrackingToMessages < ActiveRecord::Migration[8.0]
  def change
    add_column :messages, :click_count, :integer, default: 0, null: false
    add_column :messages, :first_clicked_at, :datetime

    create_table :clicks do |t|
      t.references :message, null: false, foreign_key: true
      t.references :account, null: false, foreign_key: true
      t.text :url, null: false
      t.datetime :clicked_at, null: false
      t.string :ip_address
      t.text :user_agent
      t.string :referer

      t.timestamps
    end

    add_index :clicks, [:message_id, :clicked_at]
    add_index :clicks, :clicked_at
  end
end
