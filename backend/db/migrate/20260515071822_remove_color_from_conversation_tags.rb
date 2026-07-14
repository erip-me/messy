class RemoveColorFromConversationTags < ActiveRecord::Migration[8.0]
  def change
    remove_column :conversation_tags, :color, :string
  end
end
