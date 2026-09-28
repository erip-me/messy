# After a Business App number is onboarded (coexistence), asks Meta to replay its
# contacts and chat history as smb_app_state_sync / history webhooks. Meta allows
# this only within 24h of onboarding, hence the prompt job + retries.
class WhatsappCoexistenceSyncJob < ApplicationJob
  queue_as :default

  retry_on MetaGraph::Error, wait: :polynomially_longer, attempts: 8

  def perform(integration_id)
    integration = WhatsappIntegration.find_by(id: integration_id)
    return unless integration&.active?

    requests = %w[smb_app_state_sync history].to_h do |sync_type|
      res = MetaGraph.post("#{integration.phone_id}/smb_app_data", token: integration.token,
                           body: { messaging_product: "whatsapp", sync_type: sync_type })
      [sync_type, res["request_id"]]
    end
    integration.update_column(:config, integration.config.merge(
      "coexistence_sync" => { "requested_at" => Time.current.iso8601, "request_ids" => requests }
    ))
  end
end
