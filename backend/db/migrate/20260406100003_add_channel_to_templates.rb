class AddChannelToTemplates < ActiveRecord::Migration[7.1]
  def change
    add_column :templates, :channel, :string, default: "email", null: false
  end
end
