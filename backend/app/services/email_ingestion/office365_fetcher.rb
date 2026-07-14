module EmailIngestion
  # Fetches new inbox mail for an Office365 mailbox via Microsoft Graph.
  #
  # Uses Graph's delta query on the Inbox as the sync cursor (analogous to the
  # Gmail history_id): each run walks pages from the stored deltaLink and returns
  # only messages that arrived since. Each message is pulled as raw MIME
  # (/messages/{id}/$value) so it flows through the same Mail-based Processor as
  # IMAP and Gmail. The delta cursor is primed at connect time (see GraphPush),
  # so we never bulk-import the pre-existing inbox as tickets.
  class Office365Fetcher
    GRAPH = "https://graph.microsoft.com/v1.0".freeze
    INITIAL_DELTA = "#{GRAPH}/me/mailFolders('inbox')/messages/delta?$select=id".freeze

    attr_reader :mailbox

    def initialize(mailbox)
      @mailbox = mailbox
    end

    def fetch_new_emails
      refresh_token_if_needed!
      emails = []
      url = mailbox.sync_state["delta_link"].presence || INITIAL_DELTA
      new_delta = nil

      loop do
        body = get_json(url)

        Array(body["value"]).each do |item|
          next if item["@removed"]
          msg_id = item["id"]
          next if msg_id.blank?

          begin
            raw = fetch_mime(msg_id)
            next if raw.blank?
            emails << [Mail.new(raw), msg_id]
          rescue => e
            Rails.logger.error "[Office365Fetcher] Failed to fetch/parse message #{msg_id} for mailbox #{mailbox.id}: #{e.message}"
          end
        end

        if body["@odata.nextLink"].present?
          url = body["@odata.nextLink"]
        else
          new_delta = body["@odata.deltaLink"]
          break
        end
      end

      mailbox.update!(
        sync_state: mailbox.sync_state.merge("delta_link" => new_delta).compact,
        last_synced_at: Time.current
      )

      emails
    end

    def test_connection!
      refresh_token_if_needed!
      data = get_json("#{GRAPH}/me")
      { success: true, email: data["mail"].presence || data["userPrincipalName"] }
    end

    private

    def fetch_mime(msg_id)
      resp = Faraday.get("#{GRAPH}/me/messages/#{msg_id}/$value") do |req|
        req.headers["Authorization"] = "Bearer #{access_token}"
      end
      return nil unless resp.success?
      resp.body
    end

    def get_json(url)
      resp = Faraday.get(url) do |req|
        req.headers["Authorization"] = "Bearer #{access_token}"
      end
      raise "Graph GET #{url} failed: #{resp.status} #{resp.body}" unless resp.success?
      JSON.parse(resp.body)
    end

    def access_token
      mailbox.config["access_token"]
    end

    def refresh_token_if_needed!
      config = mailbox.config
      expires_at = config["token_expires_at"]
      return if expires_at.present? && Time.parse(expires_at) > 5.minutes.from_now

      tokens = MailboxOauth::Microsoft.refresh(config["refresh_token"])
      # Preserve the existing refresh token if Microsoft didn't rotate it.
      tokens["refresh_token"] ||= config["refresh_token"]
      mailbox.update!(config: config.merge(tokens))
    end
  end
end
