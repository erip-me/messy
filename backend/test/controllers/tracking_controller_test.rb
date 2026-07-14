require "test_helper"

class TrackingControllerTest < ActionDispatch::IntegrationTest
  include TrackingLinkSigner

  def sig_for(url)
    tracking_link_signature(url, Message::CLICK_SIGNATURE_PURPOSE)
  end

  test "pixel with valid token returns PNG and creates open record" do
    message = EmailMessage.create!(
      account: accounts(:acme),
      environment: environments(:production),
      to: "track@example.com",
      subject: "Track Test",
      body: "<p>Track me</p>",
      status: :sent
    )
    token = message.tracking_token
    assert_match /\A[a-f0-9]{64}\z/, token

    # The route constraint captures "token.png" — Rails strips .png as format
    # The controller looks up by params[:token] which should be just the hex string
    assert_difference "Open.count", 1 do
      get "/track/#{token}.png"
    end

    assert_response :success
    assert_includes response.content_type, "image/png"

    open_record = Open.last
    assert_equal message, open_record.message
  end

  test "pixel with invalid token still returns PNG" do
    fake_token = "a" * 64

    get "/track/#{fake_token}.png"

    assert_response :success
    assert_includes response.content_type, "image/png"
  end

  test "click with signed url records a click and redirects to it" do
    message = messages(:email_one)
    url = "https://example.com/landing"

    assert_difference "Click.count", 1 do
      get "/track/#{message.tracking_token}/click", params: { url: url, sig: sig_for(url) }
    end

    assert_response :redirect
    assert_redirected_to url

    click = Click.last
    assert_equal message, click.message
    assert_equal url, click.url
    message.reload
    assert_equal 1, message.click_count
  end

  test "click does not follow a forged/unsigned url (no open redirect)" do
    message = messages(:email_one)

    assert_no_difference "Click.count" do
      get "/track/#{message.tracking_token}/click", params: { url: "https://evil.example" }
      assert_redirected_to "/"

      get "/track/#{message.tracking_token}/click", params: { url: "https://evil.example", sig: "deadbeef" }
      assert_redirected_to "/"
    end
  end

  test "click with valid signature but unknown token still redirects without recording" do
    fake_token = "a" * 64
    url = "https://example.com/landing"

    assert_no_difference "Click.count" do
      get "/track/#{fake_token}/click", params: { url: url, sig: sig_for(url) }
    end

    assert_redirected_to url
  end
end
