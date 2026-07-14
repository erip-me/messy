class MessagesChannel < ApplicationCable::Channel
  def subscribed
    reject and return unless current_user

    stream_from "messages_channel_#{current_user.account_id}"
  end

  def unsubscribed
    # Any cleanup needed when channel is unsubscribed
  end
end
