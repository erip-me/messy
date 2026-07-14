class VisitorPresenceChannel < ApplicationCable::Channel
  def subscribed
    unless visitor_token && account_id
      reject
      return
    end

    stream_from "visitor_presence_#{account_id}"

    rows = update_visitor_presence(true)
    broadcast_visitor_online
  end

  def heartbeat(data)
    page_data = data.slice("page_url", "page_title")
    update_visitor_presence(true, page_data: page_data)

    if page_data["page_url"].present?
      customer = Customer.find_by(account_id: account_id, anonymous_token: visitor_token)
      PageVisit.record_visit!(
        account_id: account_id,
        visitor_token: visitor_token,
        customer_id: customer&.id,
        url: page_data["page_url"],
        title: page_data["page_title"]
      )
    end
  end

  def unsubscribed
    return unless visitor_token && account_id

    update_visitor_presence(false)
    broadcast_visitor_offline
  end

  private

  def update_visitor_presence(online, page_data: {})
    # All writes are scoped to (account_id, visitor_token) pair — both are
    # now derived from trusted sources in the connection layer.
    rows = Customer.where(account_id: account_id, anonymous_token: visitor_token)
                   .update_all(online: online, last_seen_at: Time.current)

    if online
      conversation = Conversation.where(account_id: account_id, visitor_token: visitor_token)
                                 .where(status: [:open, :pending]).order(created_at: :desc).first
      if conversation
        attrs = { visitor_last_seen_at: Time.current }
        attrs[:visitor_page_url] = page_data["page_url"] if page_data["page_url"]
        attrs[:visitor_page_title] = page_data["page_title"] if page_data["page_title"]
        conversation.update_columns(attrs)
      end
    end
    rows
  end

  def broadcast_visitor_online
    ActionCable.server.broadcast(
      "operator_inbox_#{account_id}",
      { type: "visitor_online", visitor_token: visitor_token }
    )
  end

  def broadcast_visitor_offline
    ActionCable.server.broadcast(
      "operator_inbox_#{account_id}",
      { type: "visitor_offline", visitor_token: visitor_token }
    )
  end
end
