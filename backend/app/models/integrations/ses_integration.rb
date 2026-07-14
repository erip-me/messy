class SesIntegration < Integration
  before_validation { self.kind = :email }

  def access_key_id
    config['access_key_id'] || config['access_key']
  end

  def access_key_id=(value)
    config['access_key_id'] = value
  end

  def secret_access_key
    config['secret_access_key'] || config['secret_key']
  end

  def secret_access_key=(value)
    config['secret_access_key'] = value
  end

  def region
    config['region']
  end

  def region=(value)
    config['region'] = value
  end

  def source
    config['source'] || config['from_email'] || config['from']
  end

  def source=(value)
    config['source'] = value
  end

  def configuration_set
    config['configuration_set']
  end

  def configuration_set=(value)
    config['configuration_set'] = value
  end

  def deliver!(message, recipient = nil, from: nil)
    ses = Aws::SES::Client.new(
      region:region,
      access_key_id: access_key_id,
      secret_access_key: secret_access_key
    )

    from = from.presence || self.source

    # Create mail object
    mail = Mail.new do
      from      from
      to        recipient || message.to
      cc        message.cc unless recipient
      bcc       message.bcc unless recipient
      subject   message.tagged_subject
    end

    mail.text_part = Mail::Part.new do
      body Html2Text.convert(message.inject_tracking_pixel)
    end

    mail.html_part = Mail::Part.new do
      content_type 'text/html; charset=UTF-8'
      body message.tracked_html
    end

    # Add attachments to message
    message.attachments.each do |attachment|
      mail.add_file(filename: attachment.filename.to_s, content: attachment.download, mime_type: attachment.content_type)
    end

    send_params = { raw_message: { data: mail.to_s } }
    send_params[:configuration_set_name] = configuration_set if configuration_set.present?

    resp = ses.send_raw_email(send_params)

    Rails.logger.info "Email sent! Message ID: #{resp.message_id}"

    # Return in the shape DeliverMessageJob expects for provider_message_id storage
    { "messages" => [{ "id" => resp.message_id }] }
  end

  # Send a pre-built Mail::Message object via SES
  def send_raw_mail!(mail)
    ses = Aws::SES::Client.new(
      region: region,
      access_key_id: access_key_id,
      secret_access_key: secret_access_key
    )

    send_params = { raw_message: { data: mail.to_s } }
    send_params[:configuration_set_name] = configuration_set if configuration_set.present?

    ses.send_raw_email(send_params)
  end
end
