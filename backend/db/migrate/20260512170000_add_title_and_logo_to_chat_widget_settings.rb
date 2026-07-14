class AddTitleAndLogoToChatWidgetSettings < ActiveRecord::Migration[8.0]
  def change
    add_column :chat_widget_settings, :title, :string, default: "Chat with us"
  end
end
