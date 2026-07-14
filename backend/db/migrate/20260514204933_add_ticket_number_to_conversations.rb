class AddTicketNumberToConversations < ActiveRecord::Migration[8.0]
  def change
    add_column :conversations, :ticket_number, :string
    add_index :conversations, [:account_id, :ticket_number], unique: true, where: "ticket_number IS NOT NULL"
  end
end
