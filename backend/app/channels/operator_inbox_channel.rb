class OperatorInboxChannel < ApplicationCable::Channel
  def subscribed
    reject and return unless current_user
    stream_from "operator_inbox_#{current_user.account_id}"
  end
end
