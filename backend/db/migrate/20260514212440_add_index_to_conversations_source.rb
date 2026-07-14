class AddIndexToConversationsSource < ActiveRecord::Migration[8.0]
  def change
    add_index :conversations, [:account_id, :source], name: "index_conversations_on_account_id_and_source"
  end
end
