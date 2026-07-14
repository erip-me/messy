class AddWhatsappConfigToEnvironments < ActiveRecord::Migration[7.1]
  def change
    add_column :environments, :whatsapp_phone_id, :string
    add_column :environments, :whatsapp_token, :string
  end
end
