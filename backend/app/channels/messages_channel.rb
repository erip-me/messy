class MessagesChannel < ApplicationCable::Channel
  def subscribed
    account_id = subscription_account_id
    reject and return unless account_id

    stream_from "messages_channel_#{account_id}"
  end

  def unsubscribed
    # Any cleanup needed when channel is unsubscribed
  end
end
