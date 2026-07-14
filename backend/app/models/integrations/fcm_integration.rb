class FcmIntegration < Integration
  before_validation { self.kind = :mobile_push }

  def project_id
    config['project_id']
  end

  def project_id=(value)
    config['project_id'] = value
  end

  def service_account_json
    config['service_account_json']
  end

  def service_account_json=(value)
    config['service_account_json'] = value
  end

  def server_key
    config['server_key']
  end

  def server_key=(value)
    config['server_key'] = value
  end

  def deliver!(message, recipient = nil)
    to = recipient || message.to
    tokens = resolve_tokens(to, message.account)

    raise NoTokensError, "No device tokens found for #{to}" if tokens.empty?

    results = tokens.map { |token| send_push(token, message) }

    # Update last_used_at for successful deliveries
    successful_tokens = results.select { |r| r[:success] }.map { |r| r[:token] }
    DeviceToken.where(token: successful_tokens).update_all(last_used_at: Time.current) if successful_tokens.any?

    failures = results.select { |r| r[:error] }
    if failures.any? && failures.length == results.length
      raise "All push deliveries failed: #{failures.map { |f| f[:error] }.join(', ')}"
    end

    Rails.logger.info "FCM push sent to #{results.length} devices (#{failures.length} failures)"
  end

  private

  def send_push(token, message)
    fcm = build_fcm_client
    response = fcm.send_v1(
      {
        token: token,
        notification: {
          title: message.subject || "Notification",
          body: message.tagged_body
        },
        data: push_data(message),
        android: { priority: "high" },
        apns: {
          payload: { aps: { sound: "default", badge: 1 } }
        }
      }
    )

    if response[:status_code] == 404 || response[:body]&.include?("NOT_FOUND")
      DeviceToken.find_by(token: token)&.deactivate!
      return { token: token, error: "Token invalid, deactivated" }
    end

    if response[:status_code]&.between?(200, 299)
      { token: token, success: true }
    else
      { token: token, error: "FCM #{response[:status_code]}: #{response[:body]}" }
    end
  rescue StandardError => e
    DeviceToken.find_by(token: token)&.deactivate! if e.message.include?("InvalidRegistration")
    { token: token, error: e.message }
  end

  def build_fcm_client
    # FCM.new(json_key_path, project_name, http_options)
    # json_key_path accepts any object responding to :read (StringIO works)
    if service_account_json.present?
      credentials_io = StringIO.new(service_account_json)
      FCM.new(credentials_io, project_id)
    else
      FCM.new(server_key, project_id)
    end
  end

  def resolve_tokens(to, account)
    # If `to` looks like a device token (long alphanumeric string), use it directly
    if to.length > 50 && !to.include?("@")
      return [to]
    end

    # Otherwise treat `to` as customer email and look up their active tokens
    customer = account.customers.find_by(email: to.downcase.strip)
    return [] unless customer

    customer.device_tokens.active.for_platform(target_platforms).pluck(:token)
  end

  # When a separate APNs integration exists, FCM only handles Android tokens.
  # Otherwise FCM proxies to both Android and iOS via its built-in APNs relay.
  def target_platforms
    @target_platforms ||= begin
      has_apns = if environment
        environment.integrations.where(type: ApnsIntegration.name, active: true).exists? ||
          environment.account.integrations.where(type: ApnsIntegration.name, environment_id: nil, active: true).exists?
      else
        false
      end

      has_apns ? [:android] : [:android, :ios]
    end
  end
end
