class AddButtonColorsToChatWidgetSettings < ActiveRecord::Migration[8.0]
  def change
    add_column :chat_widget_settings, :button_color, :string, default: "#1e1e1e"
    add_column :chat_widget_settings, :button_text_color, :string, default: "#ffffff"
  end
end
