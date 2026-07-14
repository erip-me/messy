module EmailIngestion
  class ImapFetcher
    attr_reader :mailbox

    def initialize(mailbox)
      @mailbox = mailbox
    end

    def fetch_new_emails
      emails = []
      config = mailbox.config

      imap = Net::IMAP.new(
        config["host"],
        port: config["port"] || 993,
        ssl: config.fetch("ssl", true)
      )

      begin
        imap.login(config["username"], config["password"])
        imap.select(config["folder"] || "INBOX")

        uidvalidity = imap.responses["UIDVALIDITY"]&.last
        stored_validity = mailbox.sync_state["uidvalidity"]
        last_uid = mailbox.sync_state["last_uid"] || 0

        # If UIDVALIDITY changed, UIDs are invalid — start fresh
        if stored_validity && stored_validity != uidvalidity
          last_uid = 0
        end

        # Search for messages with UID greater than what we've seen
        uids = if last_uid > 0
                 imap.uid_search(["UID", "#{last_uid + 1}:*"])
               else
                 # First sync: get last 50 messages
                 all_uids = imap.uid_search(["ALL"])
                 all_uids.last(50)
               end

        # Filter out the last_uid itself (UID ranges are inclusive)
        uids = uids.select { |uid| uid > last_uid } if last_uid > 0
        uids = uids.compact.uniq

        return emails if uids.empty?

        # Fetch in batches of 25
        uids.each_slice(25) do |batch|
          fetch_data = imap.uid_fetch(batch, ["RFC822", "UID"])
          next unless fetch_data

          fetch_data.each do |msg|
            uid = msg.attr["UID"]
            raw = msg.attr["RFC822"]
            next unless raw

            begin
              mail = Mail.new(raw)
              emails << [mail, uid.to_s]
            rescue => e
              Rails.logger.error "[ImapFetcher] Failed to parse message UID=#{uid}: #{e.message}"
            end
          end
        end

        # Update sync state
        new_last_uid = uids.max || last_uid
        mailbox.update!(
          sync_state: { "uidvalidity" => uidvalidity, "last_uid" => new_last_uid },
          last_synced_at: Time.current
        )
      ensure
        imap.logout rescue nil
        imap.disconnect rescue nil
      end

      emails
    end

    def test_connection!
      config = mailbox.config
      imap = Net::IMAP.new(
        config["host"],
        port: config["port"] || 993,
        ssl: config.fetch("ssl", true)
      )
      begin
        imap.login(config["username"], config["password"])
        imap.select(config["folder"] || "INBOX")
        count = imap.responses["EXISTS"]&.last || 0
        { success: true, message_count: count }
      ensure
        imap.logout rescue nil
        imap.disconnect rescue nil
      end
    end
  end
end
