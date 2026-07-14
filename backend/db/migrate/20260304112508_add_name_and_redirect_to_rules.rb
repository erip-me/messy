class AddNameAndRedirectToRules < ActiveRecord::Migration[7.1]
  def change
    add_column :rules, :name, :string, default: '', null: false
    add_column :rules, :redirect_to, :string
  end
end
