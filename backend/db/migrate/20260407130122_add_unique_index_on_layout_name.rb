class AddUniqueIndexOnLayoutName < ActiveRecord::Migration[7.1]
  def change
    add_index :layouts, [:environment_id, :name], unique: true
  end
end
