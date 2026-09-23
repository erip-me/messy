# Email composer support: personal (1:1) sending identities, a default "send as"
# identity per template, and free-form caller metadata on messages.
class AddComposerFields < ActiveRecord::Migration[8.0]
  def change
    add_column :sending_identities, :personal, :boolean, default: false, null: false
    add_reference :templates, :sending_identity, foreign_key: { on_delete: :nullify }
    add_column :messages, :metadata, :jsonb, default: {}, null: false
  end
end
