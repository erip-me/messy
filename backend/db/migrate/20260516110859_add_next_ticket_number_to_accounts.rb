class AddNextTicketNumberToAccounts < ActiveRecord::Migration[8.0]
  def change
    add_column :accounts, :next_ticket_number, :integer, default: 1, null: false
  end
end
