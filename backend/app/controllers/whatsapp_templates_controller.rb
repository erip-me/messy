require 'net/http'
require 'json'

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
    uri = URI.parse("https://graph.facebook.com/v21.0/#{business_account_id}/message_templates")
    uri.query = URI.encode_www_form(fields: "name,status,category,language,components", limit: 100)

    response = meta_get(uri, token)
    return [] unless response

    (response["data"] || []).select { |t| t["status"] == "APPROVED" }
  end

  def meta_get(uri, token)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.ipaddr = Resolv::DNS.new.getresource(uri.host, Resolv::DNS::Resource::IN::A).address.to_s

    request = Net::HTTP::Get.new("#{uri.path}?#{uri.query}")
    request["Authorization"] = "Bearer #{token}"

    response = http.request(request)

    if response.code.to_i.between?(200, 299)
      JSON.parse(response.body)
    else
      Rails.logger.error "Meta API error: #{response.code} - #{response.body}"
      nil
    end
  end
end
