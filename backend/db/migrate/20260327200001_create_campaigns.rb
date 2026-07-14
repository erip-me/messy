class CreateCampaigns < ActiveRecord::Migration[7.1]
  def change
    create_table :campaigns do |t|
      t.references :account, null: false, foreign_key: true
      t.references :segment, null: true, foreign_key: true
      t.string :name, null: false
      t.string :subject, null: false
      t.string :from_email, null: false
      t.text :content
      t.string :status, default: 'draft'
      t.integer :recipient_count, default: 0
      t.datetime :sent_at
      t.timestamps
    end
    add_index :campaigns, [:account_id, :status]
  end
end
