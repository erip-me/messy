class AddWhatsappWebhookSupport < ActiveRecord::Migration[8.0]
  def change
    add_column :deliveries, :provider_message_id, :string
    add_column :deliveries, :status, :string

    add_index :deliveries, :provider_message_id, unique: true, where: "provider_message_id IS NOT NULL"
  end
end
