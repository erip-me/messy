class AddTransformersToLayouts < ActiveRecord::Migration[7.1]
  def change
    add_column :layouts, :transformers, :jsonb, default: {}
  end
end
