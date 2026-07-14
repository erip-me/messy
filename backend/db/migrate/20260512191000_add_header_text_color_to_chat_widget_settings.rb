class AddHeaderTextColorToChatWidgetSettings < ActiveRecord::Migration[8.0]
  def change
    add_column :chat_widget_settings, :header_text_color, :string
  end
end
