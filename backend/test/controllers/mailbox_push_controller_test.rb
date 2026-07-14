require "test_helper"

class MailboxPushControllerTest < ActionDispatch::IntegrationTest
  # ── Graph ──────────────────────────────────────────────────────────────────

  test "graph echoes the validation token on subscribe handshake" do
    post "/mailboxes/graph/push", params: { validationToken: "hello-123" }
    assert_response :success
    assert_equal "hello-123", response.body
    assert_match "text/plain", response.media_type
  end

  test "graph enqueues a poll for the matching subscription" do
    mailbox = Mailbox.create!(
      account: accounts(:acme), environment: environments(:production),
      name: "O365", email_address: "o365@acme.com", provider: :office365,
      config: { "refresh_token" => "r" }, sync_state: { "subscription_id" => "sub-abc" }
    )

    PollMailboxJob.expects(:perform_later).with(mailbox.id).once
    post "/mailboxes/graph/push",
      params: { value: [{ subscriptionId: "sub-abc", clientState: EmailIngestion::GraphPush.client_state }] },
      as: :json
    assert_response :accepted
  end

  test "graph ignores notifications with a bad clientState" do
    Mailbox.create!(
      account: accounts(:acme), environment: environments(:production),
      name: "O365b", email_address: "o365b@acme.com", provider: :office365,
      config: { "refresh_token" => "r" }, sync_state: { "subscription_id" => "sub-xyz" }
    )

    PollMailboxJob.expects(:perform_later).never
    post "/mailboxes/graph/push",
      params: { value: [{ subscriptionId: "sub-xyz", clientState: "wrong" }] },
      as: :json
    assert_response :accepted
  end

  # ── Gmail ──────────────────────────────────────────────────────────────────

  test "gmail push is forbidden without the shared token" do
    post "/mailboxes/gmail/push", params: {}, as: :json
    assert_response :forbidden
  end

  test "gmail push enqueues a poll for the addressed mailbox" do
    ENV["GMAIL_PUSH_TOKEN"] = "secret-tok"
    mailbox = Mailbox.create!(
      account: accounts(:acme), environment: environments(:production),
      name: "GM", email_address: "gm@acme.com", provider: :gmail,
      config: { "refresh_token" => "r" }
    )
    data = Base64.encode64({ emailAddress: "gm@acme.com", historyId: "42" }.to_json)

    PollMailboxJob.expects(:perform_later).with(mailbox.id).once
    post "/mailboxes/gmail/push?token=secret-tok",
      params: { message: { data: data } }, as: :json
    assert_response :no_content
  ensure
    ENV.delete("GMAIL_PUSH_TOKEN")
  end
end
