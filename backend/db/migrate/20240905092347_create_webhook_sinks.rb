class CreateWebhookSinks < ActiveRecord::Migration[7.1]
  def change
    create_table :webhook_sinks do |t|
      t.references :webhook, null: false, foreign_key: true
      t.string :type
      t.jsonb :config, default: [], null: false

      t.timestamps
    end
  end
end
