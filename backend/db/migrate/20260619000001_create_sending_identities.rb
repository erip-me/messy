class CreateSendingIdentities < ActiveRecord::Migration[8.0]
  def change
    create_table :sending_identities do |t|
      t.bigint :account_id, null: false
      t.string :from_name
      t.string :from_email, null: false
      t.boolean :is_default, null: false, default: false
      t.timestamps
    end
    add_index :sending_identities, :account_id
    # At most one default identity per account.
    add_index :sending_identities, :account_id, unique: true, where: "is_default",
              name: "index_sending_identities_one_default_per_account"

    # Optional per-send override of the from address.
    add_reference :messages, :sending_identity, null: true
    add_reference :campaigns, :sending_identity, null: true
    add_reference :drip_campaigns, :sending_identity, null: true
  end
end
