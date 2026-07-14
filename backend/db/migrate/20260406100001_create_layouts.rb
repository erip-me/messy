class CreateLayouts < ActiveRecord::Migration[7.1]
  def change
    create_table :layouts do |t|
      t.references :account, null: false, foreign_key: true
      t.references :environment, null: false, foreign_key: true
      t.string :name, null: false
      t.text :body, null: false
      t.boolean :is_deleted, default: false, null: false
      t.timestamps
    end

    add_reference :templates, :layout, foreign_key: true
  end
end
