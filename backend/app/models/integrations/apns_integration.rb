class ApnsIntegration < Integration
  before_validation { self.kind = :mobile_push }

  def team_id
    config['team_id']
  end

  def team_id=(value)
    config['team_id'] = value
  end

  def key_id
    config['key_id']
  end

  def key_id=(value)
    config['key_id'] = value
  end

  def private_key
    config['private_key']
  end

  def private_key=(value)
    config['private_key'] = value
  end

  def bundle_id
    config['bundle_id']
  end

  def bundle_id=(value)
    config['bundle_id'] = value
  end

  def apns_environment
    config['apns_environment'] || 'production'
  end

  def apns_environment=(value)
    config['apns_environment'] = value
  end

  def deliver!(message, recipient = nil)
    to = recipient || message.to
    tokens = resolve_tokens(to, message.account)

    raise NoTokensError, "No iOS device tokens found for #{to}" if tokens.empty?

    connection = build_connection
    begin
      results = tokens.map { |token| send_push(connection, token, message) }
    ensure
      connection.close
    end

    successful_tokens = results.select { |r| r[:success] }.map { |r| r[:token] }
    DeviceToken.where(token: successful_tokens).update_all(last_used_at: Time.current) if successful_tokens.any?

    failures = results.select { |r| r[:error] }
    if failures.any? && failures.length == results.length
      raise "All APNs deliveries failed: #{failures.map { |f| f[:error] }.join(', ')}"
    end

    Rails.logger.info "APNs push sent to #{results.length} devices (#{failures.length} failures)"
  end

  private

  def send_push(connection, token, message)
    notification = Apnotic::Notification.new(token)
    notification.alert = {
      title: message.subject || "Notification",
      body: message.tagged_body
    }
    notification.topic = bundle_id
    notification.sound = "default"
    notification.custom_payload = push_data(message)

    response = connection.push(notification)

    if response.nil?
      return { token: token, error: "APNs connection timeout" }
    end

    if response.status == "410" || (response.body && response.body.include?("Unregistered"))
      DeviceToken.find_by(token: token)&.deactivate!
      return { token: token, error: "Token unregistered, deactivated" }
    end

    if response.ok?
      { token: token, success: true }
    else
      { token: token, error: "APNs #{response.status}: #{response.body}" }
    end
  rescue StandardError => e
    { token: token, error: e.message }
  end

  def build_connection
    opts = {
      auth_method: :token,
      cert_path: StringIO.new(private_key),
      key_id: key_id,
      team_id: team_id
    }

    if apns_environment == 'sandbox'
      Apnotic::Connection.development(opts)
    else
      Apnotic::Connection.new(opts)
    end
  end

  def resolve_tokens(to, account)
    # If `to` looks like a device token (long alphanumeric string), use it directly
    if to.length > 50 && !to.include?("@")
      return [to]
    end

    # Otherwise treat `to` as customer email and look up their active iOS tokens
    customer = account.customers.find_by(email: to.downcase.strip)
    return [] unless customer

    customer.device_tokens.active.for_platform(:ios).pluck(:token)
  end
end
