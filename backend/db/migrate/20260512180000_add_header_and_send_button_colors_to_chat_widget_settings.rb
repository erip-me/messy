class AddHeaderAndSendButtonColorsToChatWidgetSettings < ActiveRecord::Migration[8.0]
  def change
    add_column :chat_widget_settings, :header_color, :string
    add_column :chat_widget_settings, :send_button_color, :string
  end
end
