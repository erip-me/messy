class CreateWebhooks < ActiveRecord::Migration[7.1]
  def change
    create_table :webhooks do |t|
      t.references :account, null: false, foreign_key: true
      t.references :environment, null: false, foreign_key: true
      t.string :url_hash, null: false
      t.string :after_success_url
      t.string :after_failure_url
      t.jsonb :allowed_referers, default: ['*']
      t.jsonb :allowed_ips, default: ['*']
      t.boolean :is_active, null: false, default: false
      t.boolean :is_deleted, null: false, default: false

      t.timestamps
    end

    add_reference :messages, :webhook, null: true, foreign_key: true
  end
end
