require "test_helper"

class WhatsappIntegrationTest < ActiveSupport::TestCase
  test "reads config accessors" do
    wi = integrations(:whatsapp)
    assert_equal "1234567890", wi.phone_id
    assert_equal "test_whatsapp_token", wi.token
    assert_equal "9876543210", wi.business_account_id
  end

  test "sets config via accessors" do
    wi = WhatsappIntegration.new(account: accounts(:acme), kind: :whatsapp)
    wi.phone_id = "111"
    wi.token = "tok"
    wi.business_account_id = "222"

    assert_equal "111", wi.config["phone_id"]
    assert_equal "tok", wi.config["token"]
    assert_equal "222", wi.config["business_account_id"]
  end

  test "build_payload returns text payload when no subject" do
    wi = integrations(:whatsapp)
    msg = WhatsappMessage.new(to: "+31647508676", body: "Hello", subject: nil)
    msg.stubs(:tagged_body).returns("Hello")

    payload = wi.send(:build_payload, msg, "31647508676")

    assert_equal "text", payload["type"]
    assert_equal "Hello", payload["text"]["body"]
  end

  test "build_payload returns template payload when subject is set" do
    wi = integrations(:whatsapp)
    msg = WhatsappMessage.new(to: "+31647508676", body: "", subject: "hello_world", tags: [])

    payload = wi.send(:build_payload, msg, "31647508676")

    assert_equal "template", payload["type"]
    assert_equal "hello_world", payload["template"]["name"]
    assert_equal "en", payload["template"]["language"]["code"]
  end

  test "build_payload includes simple parameters as body components" do
    wi = integrations(:whatsapp)
    msg = WhatsappMessage.new(to: "+31647508676", body: "", subject: "signup_otp", tags: ["123456"])

    payload = wi.send(:build_payload, msg, "31647508676")

    assert_equal "template", payload["type"]
    components = payload["template"]["components"]
    assert_equal 1, components.length
    assert_equal "body", components[0]["type"]
    assert_equal "123456", components[0]["parameters"][0]["text"]
  end

  test "format_phone_number strips non-digits" do
    wi = integrations(:whatsapp)
    assert_equal "31647508676", wi.send(:format_phone_number, "+31 647 508 676")
    assert_equal "31647508676", wi.send(:format_phone_number, "+31647508676")
    assert_equal "31647508676", wi.send(:format_phone_number, "0031647508676")
    assert_equal "971582756061", wi.send(:format_phone_number, "+971 58 275 6061")
  end
end
