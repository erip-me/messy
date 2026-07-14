class AddFolderToTemplates < ActiveRecord::Migration[7.1]
  def change
    add_reference :templates, :folder, null: true, foreign_key: true
  end
end