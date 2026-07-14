module EmailIngestion
  class GmailFetcher
    attr_reader :mailbox

    def initialize(mailbox)
      @mailbox = mailbox
    end

    def fetch_new_emails
      emails = []
      service = authorized_service

      history_id = mailbox.sync_state["history_id"]

      message_ids = if history_id
                      fetch_via_history(service, history_id)
                    else
                      fetch_initial(service)
                    end

      last_history_id = nil
      message_ids.each do |msg_id|
        begin
          gmail_msg = service.get_user_message("me", msg_id, format: "raw")
          last_history_id = gmail_msg.history_id
          decoded = Base64.urlsafe_decode64(gmail_msg.raw)
          mail = Mail.new(decoded)
          emails << [mail, msg_id]
        rescue Google::Apis::ClientError => e
          Rails.logger.error "[GmailFetcher] Failed to fetch message #{msg_id}: #{e.message}"
        rescue => e
          Rails.logger.error "[GmailFetcher] Failed to parse message #{msg_id}: #{e.message}"
        end
      end

      new_history_id = last_history_id || service.get_user_profile("me").history_id

      mailbox.update!(
        sync_state: mailbox.sync_state.merge("history_id" => new_history_id.to_s),
        last_synced_at: Time.current
      )

      emails
    end

    def test_connection!
      service = authorized_service
      profile = service.get_user_profile("me")
      { success: true, email: profile.email_address, message_count: profile.messages_total }
    end

    private

    def fetch_via_history(service, history_id)
      message_ids = []
      page_token = nil

      loop do
        response = service.list_user_histories(
          "me",
          start_history_id: history_id,
          history_types: "messageAdded",
          label_id: "INBOX",
          page_token: page_token
        )

        if response.history
          response.history.each do |h|
            h.messages_added&.each do |added|
              message_ids << added.message.id
            end
          end
        end

        page_token = response.next_page_token
        break unless page_token
      end

      message_ids.uniq
    rescue Google::Apis::ClientError => e
      if e.message.include?("404") || e.message.include?("historyId")
        # History expired, fall back to initial fetch
        Rails.logger.warn "[GmailFetcher] History expired for mailbox #{mailbox.id}, doing initial fetch"
        fetch_initial(service)
      else
        raise
      end
    end

    def fetch_initial(service)
      message_ids = []
      response = service.list_user_messages("me", q: "in:inbox", max_results: 50)
      if response.messages
        message_ids = response.messages.map(&:id)
      end
      message_ids
    end

    # Refreshed, authorized GmailService — shared with the push manager.
    def authorized_service
      refresh_token_if_needed!
      service = Google::Apis::GmailV1::GmailService.new
      service.authorization = build_authorization
      service
    end

    def build_authorization
      config = mailbox.config
      # Central OAuth app credentials; fall back to any per-mailbox creds stored
      # by the legacy connect flow so already-connected mailboxes keep working.
      credentials = Google::Auth::UserRefreshCredentials.new(
        client_id: config["client_id"].presence || MailboxOauth::Google.client_id,
        client_secret: config["client_secret"].presence || MailboxOauth::Google.client_secret,
        refresh_token: config["refresh_token"],
        scope: MailboxOauth::Google::SCOPES
      )
      credentials.access_token = config["access_token"]
      credentials.expires_at = Time.parse(config["token_expires_at"]) if config["token_expires_at"]
      credentials
    end

    def refresh_token_if_needed!
      config = mailbox.config
      return unless config["token_expires_at"]

      expires_at = Time.parse(config["token_expires_at"])
      return if expires_at > 5.minutes.from_now

      credentials = build_authorization
      credentials.fetch_access_token!

      mailbox.update!(
        config: config.merge(
          "access_token" => credentials.access_token,
          "token_expires_at" => credentials.expires_at.iso8601
        )
      )
    end
  end
end
