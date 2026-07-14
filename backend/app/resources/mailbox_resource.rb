class MailboxResource
  include Alba::Resource

  attributes :id, :name, :email_address, :provider, :active, :ticket_prefix,
             :next_ticket_number, :auto_assign, :auto_reply_enabled,
             :auto_reply_template, :auto_close_days, :notification_events,
             :last_synced_at, :environment_id, :created_at

  attribute :connected do |m|
    m.connected?
  end

  attribute :push_active do |m|
    m.push_active?
  end
end
