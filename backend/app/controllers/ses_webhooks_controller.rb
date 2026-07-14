class SesWebhooksController < ApplicationController
  skip_before_action :authenticate_user!, raise: false

  # POST /ses/webhook — AWS SNS notifications (subscription confirmation + SES events)
  def callback
    body = request.raw_post
    payload = JSON.parse(body)

    unless valid_sns_message?(payload)
      head :forbidden
      return
    end

    case payload["Type"]
    when "SubscriptionConfirmation"
      confirm_subscription(payload["SubscribeURL"])
    when "Notification"
      ProcessSesWebhookJob.perform_later(JSON.parse(payload["Message"]))
      head :ok
    else
      head :ok
    end
  end

  private

  # Verify SNS message signature using the certificate provided by AWS
  def valid_sns_message?(payload)
    signing_cert_url = payload["SigningCertURL"]
    return false unless signing_cert_url.present?

    uri = URI.parse(signing_cert_url)
    return false unless sns_host?(uri)

    cert_pem = Rails.cache.fetch("sns_cert:#{signing_cert_url}", expires_in: 24.hours) do
      Net::HTTP.get(uri)
    end
    cert = OpenSSL::X509::Certificate.new(cert_pem)
    signature = Base64.decode64(payload["Signature"])

    string_to_sign = sns_string_to_sign(payload)
    cert.public_key.verify(OpenSSL::Digest::SHA1.new, signature, string_to_sign)
  rescue => e
    Rails.logger.warn "[SesWebhooks] Signature verification failed: #{e.message}"
    false
  end

  def sns_string_to_sign(payload)
    fields = case payload["Type"]
             when "Notification"
               %w[Message MessageId Subject Timestamp TopicArn Type]
             else # SubscriptionConfirmation / UnsubscribeConfirmation
               %w[Message MessageId SubscribeURL Timestamp Token TopicArn Type]
             end

    fields.each_with_object(+"") do |field, str|
      next unless payload[field]
      str << "#{field}\n#{payload[field]}\n"
    end
  end

  def confirm_subscription(subscribe_url)
    uri = URI.parse(subscribe_url) if subscribe_url.present?
    if uri && sns_host?(uri)
      Net::HTTP.get(uri)
      Rails.logger.info "[SesWebhooks] SNS subscription confirmed"
    end
    head :ok
  end

  def sns_host?(uri)
    uri.scheme == "https" && uri.host.match?(/\Asns\.[a-z0-9-]+\.amazonaws\.com\z/)
  end
end
