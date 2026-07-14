class UpdateTemplateTriggerUniqueness < ActiveRecord::Migration[7.1]
  def change
    remove_index :templates, :environment_id, name: "index_templates_on_environment_id", if_exists: true
    add_index :templates, [:environment_id, :trigger, :channel], unique: true, name: "index_templates_on_env_trigger_channel"
  end
end
