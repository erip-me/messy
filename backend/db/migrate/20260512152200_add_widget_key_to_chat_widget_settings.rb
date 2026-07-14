class AddWidgetKeyToChatWidgetSettings < ActiveRecord::Migration[8.0]
  def change
    add_column :chat_widget_settings, :widget_key, :string
    add_index :chat_widget_settings, :widget_key, unique: true

    reversible do |dir|
      dir.up do
        ChatWidgetSettings.find_each do |s|
          s.update_column(:widget_key, SecureRandom.hex(16))
        end
      end
    end
  end
end
