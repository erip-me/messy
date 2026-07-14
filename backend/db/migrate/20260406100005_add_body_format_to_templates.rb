class AddBodyFormatToTemplates < ActiveRecord::Migration[7.1]
  def change
    add_column :templates, :body_format, :string, default: "html", null: false
  end
end
