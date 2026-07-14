class AddSendButtonTextColorToChatWidgetSettings < ActiveRecord::Migration[8.0]
  def change
    add_column :chat_widget_settings, :send_button_text_color, :string
  end
end
