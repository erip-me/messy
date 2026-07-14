require "test_helper"

class SesWebhooksControllerTest < ActionDispatch::IntegrationTest
  setup do
    # Stub SNS signature verification — the controller fetches a cert over HTTPS
    # which we can't do in tests. We test the job logic separately.
    SesWebhooksController.any_instance.stubs(:valid_sns_message?).returns(true)
  end

  test "callback returns 200 for notification" do
    ses_event = { "eventType" => "Delivery", "mail" => { "messageId" => "abc123" } }
    payload = sns_notification(ses_event)

    post "/ses/webhook", params: payload.to_json, headers: { "Content-Type" => "application/json" }

    assert_response :ok
  end

  test "callback returns 403 when signature is invalid" do
    SesWebhooksController.any_instance.stubs(:valid_sns_message?).returns(false)

    payload = sns_notification({ "eventType" => "Delivery", "mail" => { "messageId" => "abc" } })

    post "/ses/webhook", params: payload.to_json, headers: { "Content-Type" => "application/json" }

    assert_response :forbidden
  end

  test "callback handles subscription confirmation" do
    subscribe_url = "https://sns.eu-west-1.amazonaws.com/confirm?token=abc"
    payload = {
      "Type" => "SubscriptionConfirmation",
      "SubscribeURL" => subscribe_url,
      "TopicArn" => "arn:aws:sns:eu-west-1:123456:test",
      "MessageId" => "msg-1",
      "Message" => "You have chosen to subscribe",
      "Timestamp" => Time.now.iso8601,
      "SigningCertURL" => "https://sns.eu-west-1.amazonaws.com/cert.pem",
      "Signature" => Base64.encode64("fake"),
      "SignatureVersion" => "1",
      "Token" => "abc"
    }

    # Stub the HTTP GET to the subscribe URL
    Net::HTTP.expects(:get).with(URI.parse(subscribe_url)).returns("ok")

    post "/ses/webhook", params: payload.to_json, headers: { "Content-Type" => "application/json" }

    assert_response :ok
  end

  test "callback returns 200 for unknown type" do
    payload = {
      "Type" => "UnsubscribeConfirmation",
      "TopicArn" => "arn:aws:sns:eu-west-1:123456:test",
      "MessageId" => "msg-1",
      "Message" => "Unsubscribed",
      "Timestamp" => Time.now.iso8601,
      "SigningCertURL" => "https://sns.eu-west-1.amazonaws.com/cert.pem",
      "Signature" => Base64.encode64("fake"),
      "SignatureVersion" => "1"
    }

    post "/ses/webhook", params: payload.to_json, headers: { "Content-Type" => "application/json" }

    assert_response :ok
  end

  private

  def sns_notification(ses_event)
    {
      "Type" => "Notification",
      "MessageId" => "msg-#{SecureRandom.hex(4)}",
      "TopicArn" => "arn:aws:sns:eu-west-1:123456:messy-ses-events",
      "Message" => ses_event.to_json,
      "Timestamp" => Time.now.iso8601,
      "SigningCertURL" => "https://sns.eu-west-1.amazonaws.com/cert.pem",
      "Signature" => Base64.encode64("fake"),
      "SignatureVersion" => "1"
    }
  end
end
