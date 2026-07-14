class AddDripAndIntegrationIndexes < ActiveRecord::Migration[8.0]
  def change
    # drips#index aggregates executions by step and enrollments by drip; these
    # foreign keys were unindexed, forcing seq-scans that grow with the data.
    add_index :drip_step_executions, :drip_step_id, name: "index_drip_step_executions_on_drip_step_id"
    add_index :drip_step_executions, :account_id, name: "index_drip_step_executions_on_account_id"
    add_index :drip_step_executions, :message_id, name: "index_drip_step_executions_on_message_id"

    add_index :drip_steps, :account_id, name: "index_drip_steps_on_account_id"
    add_index :drip_steps, :template_id, name: "index_drip_steps_on_template_id"

    add_index :drip_campaigns, :environment_id, name: "index_drip_campaigns_on_environment_id"
    add_index :drip_enrollments, :segment_membership_id, name: "index_drip_enrollments_on_segment_membership_id"

    add_index :messages, :drip_step_id, name: "index_messages_on_drip_step_id"

    # Environment#resolve_integration filters by (account_id, kind, active).
    add_index :integrations, [:account_id, :kind, :active], name: "index_integrations_on_account_id_and_kind_and_active"
  end
end
