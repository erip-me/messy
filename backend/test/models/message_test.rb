require "test_helper"

class MessageTest < ActiveSupport::TestCase
  fixtures :all

  test "enum values for scope" do
    message = messages(:email_one)
    assert message.any?

    message.scope = :internal
    assert message.internal?

    message.scope = :external
    assert message.external?
  end

  test "enum values for status" do
    assert messages(:email_one).sent?
    assert messages(:pending_email).pending?
  end

  test "tagged_subject prepends tag" do
    message = messages(:email_one)
    expected = "[#{message.environment.tag}] #{message.subject}"
    assert_equal expected, message.tagged_subject
  end

  test "tagged_subject returns subject when tag blank" do
    message = messages(:email_one)
    message.environment.tag = ""
    assert_equal message.subject, message.tagged_subject
  end

  test "build_from creates message from template" do
    template = templates(:welcome)
    params = {
      account: accounts(:acme),
      environment: environments(:production),
      to: "test@example.com"
    }

    message = Message.build_from(params, template)
    assert_equal template, message.template
    assert_equal template.subject, message.subject
    assert_equal template.body, message.body
  end

  test "build_from without template uses provided params" do
    params = {
      account: accounts(:acme),
      environment: environments(:production),
      to: "test@example.com",
      subject: "Custom Subject",
      body: "Custom Body"
    }

    message = Message.build_from(params)
    assert_nil message.template
    assert_equal "Custom Subject", message.subject
  end

  test "generates tracking_token on create" do
    message = EmailMessage.new(
      account: accounts(:acme),
      environment: environments(:production),
      to: "test@example.com",
      subject: "Test",
      body: "<p>Test</p>"
    )
    message.save!

    assert_not_nil message.tracking_token
    assert_not_nil message.tracking_salt
  end

  test "as_json never exposes tracking_salt" do
    message = messages(:email_one)
    assert message.tracking_salt.present?, "fixture should have a salt to hide"
    refute message.as_json.key?("tracking_salt"), "tracking_salt must not be serialized"
    refute_includes message.send(:broadcast_payload).to_json, message.tracking_salt
  end

  test "inject_tracking_pixel inserts pixel before </body>" do
    message = messages(:email_one)
    message.body = "<html><body><p>Hello</p></body></html>"

    result = message.inject_tracking_pixel
    assert_includes result, '<img src='
    assert_includes result, 'width="1" height="1"'
    assert result.include?("</body>")
    assert result.index('<img') < result.index('</body>')
  end

  test "inject_tracking_pixel appends pixel when no body tag" do
    message = messages(:email_one)
    message.body = "<p>Hello</p>"

    result = message.inject_tracking_pixel
    assert_includes result, '<img src='
    assert result.end_with?('" />')
  end

  test "tracked_html rewrites links to signed click-tracking redirects and injects the pixel" do
    message = messages(:email_one)
    message.body = %(<html><body><a href="https://shop.example.com/deal">Shop</a></body></html>)

    result = message.tracked_html

    # original link is gone, replaced by a tracking redirect through the tracking domain
    assert_not_includes result, 'href="https://shop.example.com/deal"'
    assert_includes result, "/track/#{message.tracking_token}/click?url="
    assert_includes result, CGI.escape("https://shop.example.com/deal")
    assert_includes result, "sig="
    # open pixel still injected
    assert_includes result, "/track/#{message.tracking_token}.png"
  end

  test "tracked_html produces a verifiable signature" do
    message = messages(:email_one)
    url = "https://shop.example.com/deal"
    message.body = %(<a href="#{url}">Shop</a>)

    result = message.tracked_html
    sig = result[/sig=([a-f0-9]+)/, 1]

    assert_not_nil sig
    assert message.valid_tracking_link?(url, sig, Message::CLICK_SIGNATURE_PURPOSE)
  end

  test "tracked_html does not rewrite mailto, tel, anchors, or tracking-domain links" do
    message = messages(:email_one)
    unsubscribe = "#{message.account.tracking_base_url}/track/#{message.tracking_token}/unsubscribe"
    message.body = <<~HTML
      <a href="mailto:hi@example.com">Mail</a>
      <a href="tel:+15551234567">Call</a>
      <a href="#section">Jump</a>
      <a href="#{unsubscribe}">Unsubscribe</a>
    HTML

    result = message.tracked_html

    assert_includes result, 'href="mailto:hi@example.com"'
    assert_includes result, 'href="tel:+15551234567"'
    assert_includes result, 'href="#section"'
    assert_includes result, %(href="#{unsubscribe}")
    assert_not_includes result, "/click?url="
  end

  test "tracked_html does not rewrite links for security-sensitive triggers" do
    message = messages(:email_one)
    url = "https://app.example.com/validate/secret-token"

    %w[magic_link user.password_reset otp_login email_verification security_alert].each do |trig|
      message.trigger = trig
      message.body = %(<a href="#{url}">Sign in</a>)
      result = message.tracked_html

      assert message.security_sensitive?, "expected #{trig} to be security-sensitive"
      assert_includes result, %(href="#{url}"), "#{trig} link must not be rewritten"
      assert_not_includes result, "/click?url=", "#{trig} must skip click tracking"
      # open pixel is still fine to inject
      assert_includes result, "/track/#{message.tracking_token}.png"
    end
  end

  test "tracked_html does not rewrite links when the SUBJECT is security-sensitive even with a nil trigger" do
    message = messages(:email_one)
    message.trigger = nil
    url = "https://www.lalaaji.com/terms"

    ["Your Lalaaji OTP: 4757", "Sign in to your account", "Reset your password", "Verify your email"].each do |subj|
      message.subject = subj
      message.body = %(<a href="#{url}">Link</a>)
      result = message.tracked_html

      assert message.security_sensitive?, "expected subject #{subj.inspect} to be security-sensitive"
      assert_includes result, %(href="#{url}"), "links in #{subj.inspect} must not be rewritten"
      assert_not_includes result, "/click?url="
    end
  end

  test "tracked_html still rewrites ordinary notification subjects with a nil trigger" do
    message = messages(:email_one)
    message.trigger = nil
    url = "https://www.lalaaji.com/rfq/42"

    ["New bid on your RFQ - Cotton tshirts", "You have 3 new messages on Lalaaji", "New affiliate application — Ali"].each do |subj|
      message.subject = subj
      message.body = %(<a href="#{url}">View</a>)
      result = message.tracked_html

      assert_not message.security_sensitive?, "subject #{subj.inspect} should NOT be security-sensitive"
      assert_includes result, "/track/#{message.tracking_token}/click?url=", "#{subj.inspect} should be click-tracked"
    end
  end

  test "tracked_html still rewrites links for ordinary transactional triggers" do
    message = messages(:email_one)
    url = "https://shop.example.com/order/123"

    %w[order_confirmed appointment_reminder user_welcome invoice_issued].each do |trig|
      message.trigger = trig
      message.body = %(<a href="#{url}">View</a>)
      result = message.tracked_html

      assert_not message.security_sensitive?, "expected #{trig} NOT to be security-sensitive"
      assert_includes result, "/track/#{message.tracking_token}/click?url=", "#{trig} should be click-tracked"
    end
  end

  test "link_click_counts aggregates clicks per url, most clicked first" do
    message = messages(:pending_email)
    message.update!(trigger: "order_confirmed")
    req = stub(remote_ip: "1.2.3.4", user_agent: "UA", referer: nil)

    Click.track_click(message, "https://a.example/x", req)
    Click.track_click(message, "https://b.example/y", req)
    Click.track_click(message, "https://b.example/y", req)

    counts = message.link_click_counts
    assert_equal({ "https://b.example/y" => 2, "https://a.example/x" => 1 }, counts)
    assert_equal "https://b.example/y", counts.keys.first
  end

  test "parent/child message association" do
    parent = messages(:email_one)
    child = EmailMessage.create!(
      account: accounts(:acme),
      environment: environments(:production),
      parent_message: parent,
      to: "child@example.com",
      subject: "Child",
      body: "<p>Child message</p>"
    )

    assert_equal parent, child.parent_message
    assert_includes parent.child_messages, child
  end
end
