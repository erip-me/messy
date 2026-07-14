require "test_helper"

class MailboxIngestionTest < ActiveSupport::TestCase
  def build(provider:, config: {}, sync_state: {})
    Mailbox.new(
      account: accounts(:acme), environment: environments(:production),
      name: "Box", email_address: "box-#{provider}@acme.com",
      provider: provider, config: config, sync_state: sync_state
    )
  end

  test "provider enum includes office365" do
    assert_equal 2, Mailbox.providers["office365"]
  end

  test "fetcher dispatches by provider" do
    assert_instance_of EmailIngestion::ImapFetcher,      build(provider: :imap).fetcher
    assert_instance_of EmailIngestion::GmailFetcher,     build(provider: :gmail).fetcher
    assert_instance_of EmailIngestion::Office365Fetcher, build(provider: :office365).fetcher
  end

  test "push_service is present only for oauth providers" do
    assert_nil build(provider: :imap).push_service
    assert_instance_of EmailIngestion::GmailPush, build(provider: :gmail).push_service
    assert_instance_of EmailIngestion::GraphPush, build(provider: :office365).push_service
  end

  test "oauth? true for gmail and office365" do
    assert_not build(provider: :imap).oauth?
    assert build(provider: :gmail).oauth?
    assert build(provider: :office365).oauth?
  end

  test "connected? requires a refresh token for oauth providers" do
    assert_not build(provider: :gmail).connected?
    assert build(provider: :gmail, config: { "refresh_token" => "r" }).connected?
    # IMAP is connected once it has a password
    assert build(provider: :imap, config: { "password" => "p" }).connected?
  end

  test "push_active? reflects gmail watch expiration" do
    future = ((Time.current + 1.day).to_f * 1000).to_i
    past   = ((Time.current - 1.day).to_f * 1000).to_i
    assert build(provider: :gmail, sync_state: { "watch_expiration" => future }).push_active?
    assert_not build(provider: :gmail, sync_state: { "watch_expiration" => past }).push_active?
    assert_not build(provider: :gmail).push_active?
  end

  test "push_active? reflects graph subscription expiry" do
    assert build(provider: :office365, sync_state: { "subscription_expires_at" => (Time.current + 1.day).iso8601 }).push_active?
    assert_not build(provider: :office365, sync_state: { "subscription_expires_at" => (Time.current - 1.day).iso8601 }).push_active?
  end

  test "push_registered? true once a watch or subscription exists" do
    assert_not build(provider: :gmail).push_registered?
    assert build(provider: :gmail, sync_state: { "watch_expiration" => 123 }).push_registered?
    assert build(provider: :office365, sync_state: { "subscription_id" => "abc" }).push_registered?
  end
end
