# Which integrations a stored webhook was proven (by signature) to speak for.
# One POST can carry entries for several WABAs; each is processed only if the
# signing app secret is one that integration accepts.
#
# integrations.platform_verified_waba_id is the WABA our own Meta app proved
# access to (Embedded Signup). It's a column, not config, so the generic
# integrations API can't set it: config is client-writable, and a copied WABA id
# must never make platform-signed webhooks flow into another tenant's inbox.
class AddAuthorizedIntegrationsToWhatsappWebhookEvents < ActiveRecord::Migration[8.0]
  def up
    add_column :whatsapp_webhook_events, :authorized_integration_ids, :bigint, array: true, default: [], null: false
    add_column :integrations, :platform_verified_waba_id, :string
    # Events accepted before this change were signature-checked against their
    # stored integration; keep that authorization so pending ones still process.
    execute <<~SQL
      UPDATE whatsapp_webhook_events SET authorized_integration_ids = ARRAY[integration_id]
      WHERE integration_id IS NOT NULL
    SQL
  end

  def down
    remove_column :whatsapp_webhook_events, :authorized_integration_ids
    remove_column :integrations, :platform_verified_waba_id
  end
end
