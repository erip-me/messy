require 'net/http'
require 'json'

class WhatsappIntegration < Integration
  before_validation { self.kind = :whatsapp }

  def phone_id
    config['phone_id'] || environment&.whatsapp_phone_id
  end

  def phone_id=(value)
    config['phone_id'] = value
  end

  def token
    config['token'] || environment&.whatsapp_token
  end

  def token=(value)
    config['token'] = value
  end

  def business_account_id
    config['business_account_id']
  end

  def business_account_id=(value)
    config['business_account_id'] = value
  end

  def webhook_verify_token
    config['webhook_verify_token']
  end

  def webhook_verify_token=(value)
    config['webhook_verify_token'] = value
  end

  def app_secret
    config['app_secret']
  end

  def app_secret=(value)
    config['app_secret'] = value
  end

  def deliver!(message, recipient = nil)
    raise "WhatsApp phone ID not configured" unless phone_id
    raise "WhatsApp token not configured" unless token

    to = format_phone_number(recipient || message.to)
    payload = build_payload(message, to)

    uri = URI.parse("https://graph.facebook.com/v21.0/#{phone_id}/messages")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.ipaddr = Resolv::DNS.new.getresource(uri.host, Resolv::DNS::Resource::IN::A).address.to_s

    request = Net::HTTP::Post.new(uri.request_uri)
    request["Content-Type"] = "application/json"
    request["Authorization"] = "Bearer #{token}"
    request.body = payload.to_json

    response = http.request(request)

    if response.code.to_i.between?(200, 299)
      Rails.logger.info "WhatsApp message sent successfully: #{response.body}"
      JSON.parse(response.body)
    else
      error_message = "WhatsApp API error: #{response.code} - #{response.body}"
      Rails.logger.error error_message
      raise error_message
    end
  end

  private

  def build_payload(message, to)
    # Template message: subject holds the template name
    if message.subject.present?
      template_payload = {
        "name" => message.subject,
        "language" => { "code" => template_language(message) }
      }

      components = build_template_components(message)
      template_payload["components"] = components if components.present?

      {
        "messaging_product" => "whatsapp",
        "to" => to,
        "type" => "template",
        "template" => template_payload
      }
    else
      # Plain text message
      {
        "messaging_product" => "whatsapp",
        "to" => to,
        "type" => "text",
        "text" => { "body" => message.tagged_body }
      }
    end
  end

  def build_template_components(message)
    # Tags stores template components/parameters as an array
    # e.g. [{"type":"body","parameters":[{"type":"text","text":"value"}]}]
    return nil unless message.tags.is_a?(Array) && message.tags.any?

    # If tags contains component hashes (with "type" key), use them directly
    if message.tags.first.is_a?(Hash) && message.tags.first.key?("type")
      return message.tags
    end

    # Simple mode: tags is a flat array of strings used as body parameters
    # e.g. ["123456"] becomes body parameters [{type: "text", text: "123456"}]
    [{
      "type" => "body",
      "parameters" => message.tags.map { |val|
        { "type" => "text", "text" => val.to_s }
      }
    }]
  end

  def template_language(message)
    # Look up the actual language registered in Meta for this template
    resolved = resolve_template_language(message.subject)
    return resolved if resolved

    return message.language if message.language.present?
    "en"
  end

  def resolve_template_language(template_name)
    return nil unless business_account_id.present? && token.present?

    templates = fetch_approved_templates
    match = templates.find { |t| t["name"] == template_name }
    match&.dig("language")
  end

  def fetch_approved_templates
    cache_key = "whatsapp_templates/#{business_account_id}"
    Rails.cache.fetch(cache_key, expires_in: 10.minutes) do
      uri = URI.parse("https://graph.facebook.com/v21.0/#{business_account_id}/message_templates")
      uri.query = URI.encode_www_form(fields: "name,status,language", limit: 100)

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.open_timeout = 5
      http.read_timeout = 5

      request = Net::HTTP::Get.new("#{uri.path}?#{uri.query}")
      request["Authorization"] = "Bearer #{token}"

      response = http.request(request)
      if response.code.to_i.between?(200, 299)
        data = JSON.parse(response.body)
        (data["data"] || []).select { |t| t["status"] == "APPROVED" }
      else
        Rails.logger.error "Failed to fetch WhatsApp templates: #{response.code} - #{response.body}"
        []
      end
    rescue StandardError => e
      Rails.logger.error "Error fetching WhatsApp templates: #{e.message}"
      []
    end
  end

  def format_phone_number(phone)
    phone = phone.first if phone.is_a?(Array)
    parsed = Phonelib.parse(phone.to_s)
    # e164 returns "+31647508676", strip the leading +
    parsed.e164.sub(/\A\+/, '')
  end
end
