class AddPreviewToTemplates < ActiveRecord::Migration[7.1]
  def change
    add_column :templates, :preview, :string
  end
end
