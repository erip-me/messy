class RemoveOutboundConfigFromMailboxes < ActiveRecord::Migration[8.0]
  def change
    remove_column :mailboxes, :outbound_config, :jsonb, default: {}
  end
end
