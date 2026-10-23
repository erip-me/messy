# Reply-To for email messages, e.g. a contact form that sends from the site's
# own address but wants replies to go to the visitor.
class AddReplyToToMessages < ActiveRecord::Migration[8.0]
  def change
    add_column :messages, :reply_to, :string
  end
end
