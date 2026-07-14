module EmailIngestion
  # Manages Gmail push for a mailbox: a users.watch() registration that makes
  # Gmail publish to our Cloud Pub/Sub topic on every new INBOX message. The
  # Pub/Sub push subscription then POSTs to MailboxPushController#gmail.
  #
  # A watch lasts up to 7 days; RenewMailboxPushJob re-arms it daily. Requires
  # GMAIL_PUBSUB_TOPIC (and the topic must grant publish to
  # gmail-api-push@system.gserviceaccount.com — see docs/HELPDESK_OAUTH.md).
  class GmailPush
    attr_reader :mailbox

    def initialize(mailbox)
      @mailbox = mailbox
    end

    def self.configured?
      ENV["GMAIL_PUBSUB_TOPIC"].present?
    end

    # Register (or re-register) the watch and prime the history cursor so only
    # mail arriving after connect becomes tickets. Also records the connected
    # address for push lookups. Raises on failure (caller decides how loud).
    def start!
      raise "GMAIL_PUBSUB_TOPIC not configured" unless self.class.configured?

      service = fetcher.authorized_service
      profile = service.get_user_profile("me")

      request = Google::Apis::GmailV1::WatchRequest.new(
        topic_name: ENV.fetch("GMAIL_PUBSUB_TOPIC"),
        label_ids: ["INBOX"],
        label_filter_behavior: "include"
      )
      result = service.watch_user("me", request)

      mailbox.update!(
        config: mailbox.config.merge("oauth_email" => profile.email_address),
        sync_state: mailbox.sync_state.merge(
          "history_id" => result.history_id.to_s,
          "watch_expiration" => result.expiration.to_i # ms epoch
        )
      )
    end

    alias_method :renew!, :start!

    def stop!
      fetcher.authorized_service.stop_user("me")
    rescue => e
      Rails.logger.warn "[GmailPush] stop failed for mailbox #{mailbox.id}: #{e.message}"
    ensure
      mailbox.update!(sync_state: mailbox.sync_state.except("watch_expiration"))
    end

    private

    def fetcher
      @fetcher ||= GmailFetcher.new(mailbox)
    end
  end
end
