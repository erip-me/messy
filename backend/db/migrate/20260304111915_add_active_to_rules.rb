class AddActiveToRules < ActiveRecord::Migration[7.1]
  def change
    add_column :rules, :active, :boolean, default: true, null: false
  end
end
