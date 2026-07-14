# Inbox list row. Pass params[:current_user] always; pass params[:unread_counts]
# (bulk_unread_counts hash) on index to avoid per-conversation unread queries.
class ConversationResource
  include Alba::Resource

  attributes :id, :visitor_name, :visitor_email, :status, :priority, :source,
             :subject, :ticket_number, :last_message_at, :last_message_preview,
             :visitor_last_seen_at, :created_at

  attribute :assigned_user do |c|
    if (user = c.assigned_user)
      profile = user.operator_profile
      {
        id: user.id,
        name: profile&.display_name || user.name,
        avatar_url: profile&.avatar_url,
        online: profile&.currently_online? || false
      }
    end
  end

  attribute :visitor_online do |c|
    c.customer&.online || false
  end

  attribute :unread_count do |c|
    if params[:unread_counts]
      params[:unread_counts][c.id] || 0
    elsif params[:current_user]
      c.unread_count_for(params[:current_user])
    else
      0
    end
  end

  attribute :tags do |c|
    c.conversation_tags.map { |t| { id: t.id, name: t.name } }
  end
end
