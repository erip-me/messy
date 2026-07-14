class AddActiveToIntegrations < ActiveRecord::Migration[7.1]
  def change
    add_column :integrations, :active, :boolean, default: true, null: false
  end
end
