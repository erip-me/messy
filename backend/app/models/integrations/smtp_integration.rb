class SmtpIntegration < Integration
  before_validation { self.kind = :email }

  def smtp_server
    config['smtp_server']
  end

  def smtp_server=(value)
    config['smtp_server'] = value
  end

  def port
    config['port']
  end

  def port=(value)
    config['port'] = value
  end

  def username
    config['username']
  end

  def username=(value)
    config['username'] = value
  end

  def password
    config['password']
  end

  def password=(value)
    config['password'] = value
  end

  def from
    config['from']
  end

  def from=(value)
    config['from'] = value
  end

  def deliver!(message, recipient = nil, from: nil)
    from_line = from.presence || self.from.to_s
    # Create mail object
    mail = Mail.new do
      from      from_line
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

    envelope_to = mail.destinations
    envelope_from = Mail::Address.new(from).address

    Net::SMTP.start(smtp_server, port) do |smtp|
      smtp.send_message mail.to_s, envelope_from, envelope_to
    end
  end
end