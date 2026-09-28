# Maps WhatsApp Cloud API webhooks (including Business App coexistence) onto the
# shared inbox: Customer = WhatsApp contact, Conversation(source: whatsapp) = the
# thread with one business number, ConversationMessage = one WhatsApp message.
#
# Every write is keyed on a Meta id behind a unique index, so a replayed webhook
# is a no-op and never re-fires the inbound hook or queues a second download.
#
# metadata["whatsapp"]["source"] records who sent a message:
#   customer     - the contact (messages webhook, or history thread message from them)
#   business_app - a human on the WhatsApp Business App (smb_message_echoes, or a
#                  history message from the business number)
#   api          - sent by Messy through the Cloud API
class WhatsappInbox
  include DeliveryStatusUpdating

  class WindowClosed < StandardError; end
  class InvalidParams < StandardError; end

  MEDIA_TYPES = %w[image audio video document sticker].freeze
  STATUS_RANK = { "accepted" => 0, "sent" => 1, "delivered" => 2, "read" => 3, "played" => 4, "failed" => 99 }.freeze
  INBOUND_EVENT = "whatsapp.inbound_message".freeze

  attr_reader :integration, :account

  # Template spec from request params; components are forwarded to Meta verbatim.
  def self.template_from(raw)
    h = raw.respond_to?(:to_unsafe_h) ? raw.to_unsafe_h : raw.to_h
    raise InvalidParams, "template.name and template.language are required" if h["name"].blank? || h["language"].blank?
    { name: h["name"].to_s, language: h["language"].to_s, components: h["components"].presence }.compact
  end

  def initialize(integration)
    @integration = integration
    @account = integration.account
  end

  # Delivery statuses are always tracked. Conversations (inbound messages, echoes,
  # history, contacts) are only captured for integrations with the inbox enabled,
  # so turning this on never floods an existing send-only workspace's inbox.
  def process(field, value)
    return unless value.is_a?(Hash)

    case field
    when "messages"
      Array(value["statuses"]).each { |s| record_status(s) }
      Array(value["errors"]).each { |e| note_error!("webhook", e) }
      return unless integration.inbox_enabled?
      names = Array(value["contacts"]).to_h { |c| [c["wa_id"], c.dig("profile", "name")] }
      Array(value["messages"]).each { |m| record_message(m, wa_id: m["from"], source: "customer", name: names[m["from"]]) }
    when "smb_message_echoes", "history", "smb_app_state_sync"
      process_coexistence(field, value) if integration.inbox_enabled?
    when "account_update"
      update_config!("last_account_update" => value.slice("event", "disconnection_info").merge("at" => Time.current.iso8601))
    end
  end

  def process_coexistence(field, value)
    case field
    when "smb_message_echoes"
      Array(value["message_echoes"]).each { |m| record_message(m, wa_id: m["to"], source: "business_app") }
    when "history"
      Array(value["history"]).each do |chunk|
        Array(chunk["errors"]).each { |e| note_error!("history", e) }
        Array(chunk["threads"]).each do |thread|
          Array(thread["messages"]).each do |m|
            source = m["from"] == thread["id"] ? "customer" : "business_app"
            record_message(m, wa_id: thread["id"], source: source, history: true)
          end
        end
      end
    when "smb_app_state_sync"
      Array(value["state_sync"]).each { |s| sync_contact(s["contact"]) if s["type"] == "contact" && s["action"] == "add" }
    end
  end

  # Free-form text needs an open customer service window; templates are always
  # allowed. Returns the stored ConversationMessage.
  def send_message(conversation, text: nil, template: nil, user: nil)
    raise WindowClosed if text && !conversation.whatsapp_free_form_allowed?

    to = conversation.customer.whatsapp_id
    response = text ? integration.send_text(to, text) : integration.send_template(to, **template)
    wamid = response.dig("messages", 0, "id")
    whatsapp = { "source" => "api", "type" => text ? "text" : "template",
                 "template" => template&.stringify_keys, "integration_id" => integration.id }.compact

    message = begin
      conversation.conversation_messages.create!(
        account: account, sender_type: "User", sender_id: user&.id, message_type: :text,
        content: text || "[template] #{template[:name]}", external_id: wamid, delivery_status: "accepted",
        metadata: { "whatsapp" => whatsapp }
      )
    rescue ActiveRecord::RecordNotUnique
      # A webhook for this wamid (an echo) got stored first; it is still our send.
      existing = ConversationMessage.find_by!(account_id: account.id, external_id: wamid)
      existing.update!(sender_id: user&.id, metadata: existing.metadata.merge("whatsapp" => whatsapp))
      existing
    end

    # Statuses that arrived while the message row didn't exist yet.
    latest = WhatsappMessageStatus.where(wamid: wamid).pluck(:status).max_by { |s| STATUS_RANK.fetch(s, -1) }
    message.update!(delivery_status: latest) if latest && !status_superseded?(message.delivery_status, latest)
    message
  rescue MetaGraph::Error => e
    note_error!("send", { "code" => e.code, "title" => e.message })
    raise
  end

  # Identifies the thread between this business number and a contact.
  def thread_token(wa_id)
    "whatsapp_#{integration.phone_id}_#{wa_id}"
  end

  def conversation_for(wa_id, name: nil)
    customer = find_or_create_customer(wa_id, name)
    conversation = account.conversations.create_or_find_by!(
      visitor_token: thread_token(customer.whatsapp_id), source: :whatsapp
    ) do |c|
      c.environment = integration.environment || account.environments.first
      c.customer = customer
      c.visitor_name = name.presence || "+#{customer.whatsapp_id}"
      c.status = :open
      c.metadata = { "whatsapp_integration_id" => integration.id }
    end
    conversation.update!(customer: customer) if conversation.customer_id != customer.id
    conversation.update!(visitor_name: name) if name.present? && conversation.visitor_name != name
    conversation
  end

  private

  def record_message(m, wa_id:, source:, name: nil, history: false)
    return if m["id"].blank? || wa_id.blank?

    conversation = conversation_for(wa_id, name: name)
    inbound = source == "customer"
    message = conversation.conversation_messages.create!(
      account: account,
      sender_type: inbound ? "Customer" : "User",
      sender_id: inbound ? conversation.customer_id : nil,
      message_type: MEDIA_TYPES.include?(m["type"]) ? :attachment : :text,
      content: preview(m),
      external_id: m["id"],
      delivery_status: inbound ? nil : m.dig("history_context", "status")&.downcase,
      created_at: m["timestamp"].present? ? Time.zone.at(m["timestamp"].to_i) : Time.current,
      metadata: { "whatsapp" => {
        "source" => source, "type" => m["type"], "history" => (true if history),
        "context_id" => m.dig("context", "id"), "media" => media_info(m),
        "integration_id" => integration.id, "raw" => m
      }.compact }
    )

    DownloadWhatsappMediaJob.perform_later(message.id) if media_info(m)
    if inbound && !history
      conversation.update!(status: :open) if conversation.status.in?(%w[resolved closed snoozed])
      ActiveSupport::Notifications.instrument(INBOUND_EVENT, message: message)
    end
    message
  rescue ActiveRecord::RecordNotUnique
    nil
  end

  def record_status(s)
    wamid, status = s["id"], s["status"]
    return if wamid.blank? || status.blank?

    WhatsappMessageStatus.create!(account: account, wamid: wamid, status: status,
                                  occurred_at: s["timestamp"].present? ? Time.zone.at(s["timestamp"].to_i) : nil,
                                  payload: s)

    if (message = ConversationMessage.find_by(account_id: account.id, external_id: wamid)) &&
       !status_superseded?(message.delivery_status, status)
      message.update!(delivery_status: status)
    end

    if (delivery = Delivery.find_by(account_id: account.id, provider_message_id: wamid)) &&
       !status_superseded?(delivery.status, status)
      attrs = { status: status }
      attrs[:error] = s["errors"].map { |e| "#{e["code"]}: #{e["title"]}" }.join("; ") if s["errors"].present?
      delivery.update!(attrs)
      update_message_status(delivery.message, status)
    end

    Array(s["errors"]).each { |e| note_error!("status", e.merge("wamid" => wamid)) }
  rescue ActiveRecord::RecordNotUnique
    nil
  end

  def find_or_create_customer(wa_id, name)
    customer = account.customers.find_by(whatsapp_id: wa_id) ||
               account.customers.where(whatsapp_id: nil).find_by(phone: ["+#{wa_id}", wa_id])
    if customer
      customer.update!(whatsapp_id: wa_id) if customer.whatsapp_id.nil?
    else
      customer = account.customers.create_or_find_by!(whatsapp_id: wa_id) { |c| c.phone = "+#{wa_id}" }
    end
    if name.present? && customer.first_name.blank?
      first, last = name.split(" ", 2)
      customer.update!(first_name: first, last_name: last)
    end
    customer
  end

  def sync_contact(contact)
    return unless contact.is_a?(Hash) && contact["phone_number"].present?
    find_or_create_customer(contact["phone_number"].delete("+"), contact["full_name"] || contact["first_name"])
  end

  def media_info(m)
    media = m[m["type"]]
    return nil unless MEDIA_TYPES.include?(m["type"]) && media.is_a?(Hash) && media["id"].present?
    media.slice("id", "mime_type", "sha256", "filename", "caption", "voice", "animated")
  end

  def preview(m)
    type = m["type"]
    body = m[type].is_a?(Hash) ? m[type] : {}
    text = case type
           when "text" then body["body"]
           when *MEDIA_TYPES then body["caption"].presence || body["filename"]
           when "button" then body["text"]
           when "interactive" then (body["button_reply"] || body["list_reply"] || {})["title"]
           when "reaction" then "Reacted #{body["emoji"]}".strip
           when "location" then [body["name"], body["address"], [body["latitude"], body["longitude"]].compact.join(",")].compact_blank.join(" · ")
           when "contacts" then Array(m["contacts"]).map { |c| c.dig("name", "formatted_name") }.compact.join(", ")
           end
    text.presence || "[#{type || "unknown"}]"
  end

  def note_error!(source, error)
    update_config!("last_error" => { "at" => Time.current.iso8601, "source" => source }
      .merge(error.to_h.slice("code", "title", "message", "wamid")).compact)
  end

  def update_config!(attrs)
    integration.update_column(:config, integration.reload.config.merge(attrs))
  end
end
