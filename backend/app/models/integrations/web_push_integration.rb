class WebPushIntegration < Integration
  before_validation { self.kind = :web_push }

  def vapid_public_key
    config['vapid_public_key']
  end

  def vapid_public_key=(value)
    config['vapid_public_key'] = value
  end

  def vapid_private_key
    config['vapid_private_key']
  end

  def vapid_private_key=(value)
    config['vapid_private_key'] = value
  end

  def vapid_subject
    config['vapid_subject']
  end

  def vapid_subject=(value)
    config['vapid_subject'] = value
  end

  def deliver!(message, recipient = nil)
    to = recipient || message.to
    subscriptions = resolve_subscriptions(to, message.account)

    raise NoTokensError, "No web push subscriptions found for #{to}" if subscriptions.empty?

    results = subscriptions.map { |sub| send_push(sub, message) }

    failures = results.select { |r| r[:error] }
    if failures.any? && failures.length == results.length
      raise "All web push deliveries failed: #{failures.map { |f| f[:error] }.join(', ')}"
    end

    Rails.logger.info "Web push sent to #{results.length} subscriptions (#{failures.length} failures)"
  end

  private

  def send_push(subscription_record, message)
    subscription = parse_subscription(subscription_record.token)

    payload = {
      title: message.subject || "Notification",
      body: message.tagged_body,
      data: { message_id: message.id.to_s }
    }.to_json

    WebPush.payload_send(
      message: payload,
      endpoint: subscription['endpoint'],
      p256dh: subscription.dig('keys', 'p256dh'),
      auth: subscription.dig('keys', 'auth'),
      vapid: {
        subject: vapid_subject,
        public_key: vapid_public_key,
        private_key: vapid_private_key
      },
      urgency: 'high'
    )

    subscription_record.touch_last_used!
    { token: subscription_record.id, success: true }
  rescue WebPush::ExpiredSubscription, WebPush::InvalidSubscription
    subscription_record.deactivate!
    { token: subscription_record.id, error: "Subscription expired, deactivated" }
  rescue StandardError => e
    { token: subscription_record.id, error: e.message }
  end

  def parse_subscription(token_string)
    JSON.parse(token_string)
  rescue JSON::ParserError
    # Fallback: treat as raw endpoint for simple implementations
    { 'endpoint' => token_string, 'keys' => {} }
  end

  def resolve_subscriptions(to, account)
    # If `to` looks like a JSON subscription or URL, can't look up by email
    if to.start_with?('{') || to.start_with?('http')
      return []
    end

    customer = account.customers.find_by(email: to.downcase.strip)
    return [] unless customer

    customer.device_tokens.active.for_platform(:web)
  end
end
