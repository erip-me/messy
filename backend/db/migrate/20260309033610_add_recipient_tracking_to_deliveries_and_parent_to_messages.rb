class AddRecipientTrackingToDeliveriesAndParentToMessages < ActiveRecord::Migration[7.1]
  def change
    add_column :deliveries, :recipient, :string

    add_reference :messages, :parent_message, foreign_key: { to_table: :messages }, null: true
  end
end
