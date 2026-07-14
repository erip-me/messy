class CreateChatWidgetSettings < ActiveRecord::Migration[8.0]
  def change
    create_table :chat_widget_settings do |t|
      t.references :account, null: false, foreign_key: true, index: { unique: true }
      t.boolean :enabled, null: false, default: true
      t.string :primary_color, default: "#3B86E4"
      t.string :secondary_color, default: "#ffffff"
      t.string :text_color, default: "#ffffff"
      t.string :position, default: "bottom-right"
      t.text :greeting_message, default: "Hi there! How can we help?"
      t.text :offline_message, default: "We are currently offline. Leave a message and we'll get back to you."
      t.boolean :require_email_before_chat, default: false
      t.boolean :show_operator_avatars, default: true
      t.boolean :show_operator_count, default: true
      t.boolean :business_hours_enabled, default: false
      t.jsonb :business_hours, default: {}
      t.string :timezone, default: "UTC"
      t.integer :auto_close_hours, default: 24
      t.jsonb :welcome_triggers, default: []
      t.jsonb :allowed_domains, default: ["*"]
      t.timestamps
    end
  end
end
