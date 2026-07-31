class OperatorPresenceChannel < ApplicationCable::Channel
  def subscribed
    @account_id = subscription_account_id
    reject and return unless @account_id

    stream_from "operator_presence_#{@account_id}"

    ensure_profile!
    # Only update heartbeat, don't change availability — respect the user's last choice
    profile = current_user.operator_profile
    profile.heartbeat! if profile&.online?
    broadcast_presence_list
  end

  def heartbeat
    profile = current_user.operator_profile
    profile&.heartbeat! if profile&.online?
  end

  def set_availability(data)
    profile = current_user.operator_profile
    return unless profile

    profile.update!(availability: data["status"], last_heartbeat_at: Time.current)
    broadcast_presence_list
  end

  def unsubscribed
    return unless current_user && @account_id
    broadcast_presence_list
  end

  def self.broadcast_presence_for(account_id)
    online_operators = OperatorProfile.where(account_id: account_id)
                                      .available
                                      .includes(:avatar_attachment, :avatar_blob)
    operator_list = online_operators.map(&:as_public_json)

    ActionCable.server.broadcast(
      "operator_presence_#{account_id}",
      { type: "presence_update", operators: operator_list }
    )

    ActionCable.server.broadcast(
      "widget_config_#{account_id}",
      { type: "operator_count", count: operator_list.length, operators: operator_list }
    )
  end

  private

  # NOTE: OperatorProfile is has_one per user and carries a single account_id, so a
  # multi-workspace operator has a profile in only one workspace and won't appear
  # in the other's presence list. Making profiles per-workspace is a separate
  # change; this method deliberately keeps the existing single-profile behaviour
  # rather than silently creating a second one.
  def ensure_profile!
    current_user.operator_profile || current_user.create_operator_profile!(
      account_id: @account_id,
      public_name: current_user.name || current_user.email.split("@").first
    )
  end

  def broadcast_presence_list
    self.class.broadcast_presence_for(@account_id)
  end
end
