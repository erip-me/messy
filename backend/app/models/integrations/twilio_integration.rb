class TwilioIntegration < Integration
  before_validation { self.kind = :sms }

  def sid
    config['sid']
  end

  def sid=(value)
    config['sid'] = value
  end

  def token
    config['token']
  end

  def token=(value)
    config['token'] = value
  end

  def from
    config['from']
  end

  def from=(value)
    config['from'] = value
  end

  def deliver!(message, recipient = nil)
    client = Twilio::REST::Client.new(sid, token)

    result = client.messages.create(
      from: from,
      to: recipient || message.to,
      body: message.tagged_body
    )

    Rails.logger.info "SMS sent! Message SID: #{result.sid}"
    result.sid
  end
end