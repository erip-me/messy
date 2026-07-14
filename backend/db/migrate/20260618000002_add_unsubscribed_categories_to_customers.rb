class AddUnsubscribedCategoriesToCustomers < ActiveRecord::Migration[8.0]
  def change
    # Category-level opt-out (e.g. "marketing"), separate from the hard
    # per-channel block in `unsubscribed_channels`. Lets a customer stop drip /
    # marketing messages without also blocking transactional/system emails.
    add_column :customers, :unsubscribed_categories, :jsonb, default: {}
  end
end
