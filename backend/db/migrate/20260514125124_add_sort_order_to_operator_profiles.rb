class AddSortOrderToOperatorProfiles < ActiveRecord::Migration[8.0]
  def change
    add_column :operator_profiles, :sort_order, :integer, default: 0, null: false
  end
end
