class WidgetConfigChannel < ApplicationCable::Channel
  def subscribed
    # account_id is now always derived from a trusted source (JWT or widget_key lookup)
    # in the connection, so we just need to check it's present.
    reject and return unless account_id

    stream_from "widget_config_#{account_id}"
  end
end
