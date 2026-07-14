class ConversationAutoAssigner
  def self.assign(conversation)
    new(conversation).assign
  end

  def initialize(conversation)
    @conversation = conversation
    @account = conversation.account
  end

  def assign
    operator = find_operator
    return nil unless operator

    @conversation.update!(assigned_user_id: operator.user_id)
    ConversationAssignment.create!(
      conversation: @conversation,
      assigned_to_id: operator.user_id
    )

    operator.user
  end

  private

  def find_operator
    profiles = OperatorProfile
      .where(account_id: @account.id, auto_assign: true)
      .includes(:user)
      .order(:sort_order, :id)
      .to_a

    open_counts = Conversation.where(account_id: @account.id, status: [:open, :pending])
                              .where(assigned_user_id: profiles.map(&:user_id))
                              .group(:assigned_user_id).count

    online = profiles.select(&:currently_online?)
    available = online.select { |p| (open_counts[p.user_id] || 0) < p.max_concurrent_chats }
    available.min_by { |p| open_counts[p.user_id] || 0 }
  end
end
