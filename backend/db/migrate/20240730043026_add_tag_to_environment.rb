class AddTagToEnvironment < ActiveRecord::Migration[7.1]
  def change
    add_column :environments, :tag, :string, null: true
  end
end
