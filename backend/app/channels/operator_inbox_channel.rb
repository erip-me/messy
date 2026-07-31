class OperatorInboxChannel < ApplicationCable::Channel
  def subscribed
    account_id = subscription_account_id
    reject and return unless account_id

    stream_from "operator_inbox_#{account_id}"
  end
end
