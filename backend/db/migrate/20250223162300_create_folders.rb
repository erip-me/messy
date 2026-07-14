class CreateFolders < ActiveRecord::Migration[7.1]
  def change
    create_table :folders do |t|
      t.references :account, null: false, foreign_key: true
      t.references :environment, null: false, foreign_key: true
      t.references :parent_folder, null: true, foreign_key: { to_table: :folders }
      t.string :name, null: false
      t.boolean :is_deleted, null: false, default: false

      t.timestamps
    end

    add_index :folders, [:account_id, :environment_id]
  end
end