module EmailIngestion
  # Manages Office365 push for a mailbox: a Microsoft Graph subscription on the
  # Inbox that POSTs change notifications to MailboxPushController#graph when new
  # mail is created. Graph validates the notificationUrl synchronously on create
  # (echo of validationToken), so start! only succeeds when API_URL is publicly
  # reachable — in dev/test it will raise and the mailbox falls back to polling.
  #
  # Mail subscriptions live at most ~3 days; RenewMailboxPushJob patches the
  # expiry every few hours (recreating if it lapsed).
  class GraphPush
    GRAPH = "https://graph.microsoft.com/v1.0".freeze
    # Graph caps message subscriptions at 4230 minutes (~2.94 days).
    MAX_MINUTES = 4230

    attr_reader :mailbox

    def initialize(mailbox)
      @mailbox = mailbox
    end

    def self.client_state
      ENV["GRAPH_WEBHOOK_CLIENT_STATE"].presence || "messy-helpdesk"
    end

    def start!
      resp = graph(:post, "#{GRAPH}/subscriptions", {
        changeType: "created",
        notificationUrl: "#{ENV.fetch('API_URL')}/mailboxes/graph/push",
        resource: "me/mailFolders('inbox')/messages",
        expirationDateTime: expiry,
        clientState: self.class.client_state
      })
      raise "Graph subscribe failed: #{resp.status} #{resp.body}" unless resp.success?

      data = JSON.parse(resp.body)
      mailbox.update!(sync_state: mailbox.sync_state.merge(
        "subscription_id" => data["id"],
        "subscription_expires_at" => data["expirationDateTime"]
      ))
    end

    def renew!
      sub_id = mailbox.sync_state["subscription_id"]
      return start! if sub_id.blank?

      resp = graph(:patch, "#{GRAPH}/subscriptions/#{sub_id}", { expirationDateTime: expiry })
      if resp.success?
        mailbox.update!(sync_state: mailbox.sync_state.merge(
          "subscription_expires_at" => JSON.parse(resp.body)["expirationDateTime"]
        ))
      else
        # Subscription expired or was deleted server-side — recreate it.
        Rails.logger.warn "[GraphPush] renew failed for mailbox #{mailbox.id} (#{resp.status}); recreating"
        start!
      end
    end

    def stop!
      sub_id = mailbox.sync_state["subscription_id"]
      return if sub_id.blank?
      graph(:delete, "#{GRAPH}/subscriptions/#{sub_id}")
    rescue => e
      Rails.logger.warn "[GraphPush] stop failed for mailbox #{mailbox.id}: #{e.message}"
    ensure
      mailbox.update!(sync_state: mailbox.sync_state.except("subscription_id", "subscription_expires_at"))
    end

    private

    def expiry
      (Time.current + MAX_MINUTES.minutes).utc.iso8601
    end

    def graph(method, url, body = nil)
      refresh_token_if_needed!
      Faraday.new.run_request(method, url, body&.to_json, {
        "Authorization" => "Bearer #{mailbox.config['access_token']}",
        "Content-Type" => "application/json"
      })
    end

    def refresh_token_if_needed!
      config = mailbox.config
      expires_at = config["token_expires_at"]
      return if expires_at.present? && Time.parse(expires_at) > 5.minutes.from_now

      tokens = MailboxOauth::Microsoft.refresh(config["refresh_token"])
      tokens["refresh_token"] ||= config["refresh_token"]
      mailbox.update!(config: config.merge(tokens))
    end
  end
end
