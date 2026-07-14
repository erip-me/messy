require "test_helper"

class MailboxesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:admin)
    @headers = auth_headers(@user)
  end

  test "index returns all mailboxes for account" do
    get "/mailboxes", headers: @headers
    assert_response :success
    data = JSON.parse(response.body)
    assert data["mailboxes"].is_a?(Array)
    assert data["mailboxes"].any? { |m| m["name"] == "Support" }
  end

  test "show returns single mailbox" do
    get "/mailboxes/#{mailboxes(:support).id}", headers: @headers
    assert_response :success
    data = JSON.parse(response.body)
    assert_equal "Support", data["mailbox"]["name"]
  end

  test "create creates a new mailbox" do
    assert_difference "Mailbox.count", 1 do
      post "/mailboxes", headers: @headers, params: {
        name: "Sales", email_address: "sales@acme.com", provider: "imap",
        ticket_prefix: "SLS", auto_assign: true,
        config: { host: "imap.gmail.com", port: "993", username: "sales@acme.com", password: "test" }
      }
    end
    assert_response :created
    data = JSON.parse(response.body)
    assert_equal "Sales", data["mailbox"]["name"]
    assert_equal "SLS", data["mailbox"]["ticket_prefix"]
  end

  test "update modifies mailbox" do
    patch "/mailboxes/#{mailboxes(:support).id}", headers: @headers, params: { name: "Updated Support" }
    assert_response :success
    assert_equal "Updated Support", mailboxes(:support).reload.name
  end

  test "destroy deletes mailbox" do
    assert_difference "Mailbox.count", -1 do
      delete "/mailboxes/#{mailboxes(:support).id}", headers: @headers
    end
    assert_response :no_content
  end

  test "oauth_url rejects IMAP mailboxes" do
    get "/mailboxes/#{mailboxes(:support).id}/oauth_url", headers: @headers
    assert_response :unprocessable_entity
  end

  test "oauth_url returns a signed Google consent URL for gmail" do
    ENV["GOOGLE_OAUTH_CLIENT_ID"] = "cid.apps.googleusercontent.com"
    ENV["GOOGLE_OAUTH_CLIENT_SECRET"] = "csecret"
    ENV["API_URL"] = "https://api.messy.sh"
    mailbox = Mailbox.create!(
      account: accounts(:acme), environment: environments(:production),
      name: "GM", email_address: "gm-oauth@acme.com", provider: :gmail
    )

    get "/mailboxes/#{mailbox.id}/oauth_url", headers: @headers
    assert_response :success
    url = JSON.parse(response.body)["url"]
    assert_includes url, "accounts.google.com/o/oauth2/v2/auth"
    assert_includes url, "state="
    assert_includes url, "gmail.readonly"
  ensure
    ENV.delete("GOOGLE_OAUTH_CLIENT_ID")
    ENV.delete("GOOGLE_OAUTH_CLIENT_SECRET")
    ENV.delete("API_URL")
  end

  test "show returns 404 for other account mailbox" do
    other_mailbox = Mailbox.create!(
      account: accounts(:other_co), environment: environments(:other_env),
      name: "Other", email_address: "other@other.com", provider: :imap
    )
    get "/mailboxes/#{other_mailbox.id}", headers: @headers
    assert_response :not_found
  end
end
