class AddUniqueIndexToDripStepExecutions < ActiveRecord::Migration[8.0]
  def change
    # Each step runs at most once per enrollment (re-entry creates a new
    # enrollment). DB-level backstop against double-processing a step.
    add_index :drip_step_executions, [:drip_enrollment_id, :drip_step_id], unique: true,
              name: "index_drip_step_executions_on_enrollment_and_step"
  end
end
