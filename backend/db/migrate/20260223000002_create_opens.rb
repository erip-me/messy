class CreateOpens < ActiveRecord::Migration[7.0]
  def change
    create_table :opens do |t|
      t.references :message, null: false, foreign_key: true
      t.datetime :opened_at, null: false
      t.string :ip_address
      t.text :user_agent
      t.string :referer
      t.timestamps
    end
    
    add_index :opens, [:message_id, :opened_at]
    add_index :opens, :opened_at
  end
end