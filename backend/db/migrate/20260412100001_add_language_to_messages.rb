class AddLanguageToMessages < ActiveRecord::Migration[7.1]
  def change
    add_column :messages, :language, :string
  end
end
