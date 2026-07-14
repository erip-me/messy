# Full conversation view for the inbox side panel.
class ConversationDetailResource < ConversationResource
  attributes :visitor_page_url, :visitor_page_title, :visitor_user_agent,
             :visitor_ip, :visitor_country, :rating, :rating_comment,
             :first_response_at, :resolved_at, :snoozed_until,
             :customer_id, :environment_id

  # Email tickets carry their thread details; the key is omitted for chat.
  attribute :email_thread, if: proc { |c| c.source_email? && c.email_thread } do |c|
    et = c.email_thread
    {
      ticket_number: et.ticket_number,
      from_email: et.from_email,
      from_name: et.from_name,
      subject: et.subject,
      cc_list: et.cc_list,
      mailbox_name: et.mailbox.name,
      mailbox_id: et.mailbox_id
    }
  end
end
