class WhatsappTemplatesController < ApplicationController
  include ApiAuthentication

  # GET /whatsapp_templates
  def index
    integration = @environment&.integrations&.whatsapp&.first || @account&.integrations&.whatsapp&.first

    unless integration
      return render json: { error: "No WhatsApp integration configured" }, status: :not_found
    end

    business_account_id = integration.business_account_id
    unless business_account_id
      return render json: { error: "WhatsApp Business Account ID not configured" }, status: :unprocessable_entity
    end

    templates = fetch_templates(business_account_id, integration.token)

    render json: {
      templates: templates.map { |t|
        {
          name: t["name"],
          status: t["status"],
          category: t["category"],
          language: t["language"],
          components: t["components"],
          id: t["id"]
        }
      }
    }
  end

  private

  def fetch_templates(business_account_id, token)
    data = MetaGraph.get("#{business_account_id}/message_templates", token: token,
                         fields: "name,status,category,language,components", limit: 100)
    (data["data"] || []).select { |t| t["status"] == "APPROVED" }
  rescue MetaGraph::Error => e
    Rails.logger.error "Meta API error: #{e.message}"
    []
  end
end
