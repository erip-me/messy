class CreateEmailMessageDetails < ActiveRecord::Migration[8.0]
  def change
    create_table :email_message_details do |t|
      t.references :conversation_message, null: false, foreign_key: true, index: false
      t.string :message_id_header
      t.string :in_reply_to_header
      t.string :from_email
      t.string :from_name
      t.string :to_email
      t.jsonb :cc_list, default: []
      t.jsonb :bcc_list, default: []
      t.text :html_body
      t.text :text_body
      t.jsonb :raw_headers, default: {}
      t.string :provider_uid
      t.timestamps
    end

    add_index :email_message_details, :conversation_message_id, unique: true
    add_index :email_message_details, :message_id_header
    add_index :email_message_details, :provider_uid
  end
end
