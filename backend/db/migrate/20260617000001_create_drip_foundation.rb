class CreateDripFoundation < ActiveRecord::Migration[8.0]
  def change
    # --- Segment enter/exit history (history-preserving; rejoin = new row) ---
    create_table :segment_memberships do |t|
      t.bigint :account_id, null: false
      t.bigint :segment_id, null: false
      t.bigint :customer_id, null: false
      t.datetime :entered_at, null: false
      t.datetime :exited_at # null => currently a member
      t.timestamps
    end
    add_index :segment_memberships, [:segment_id, :customer_id, :exited_at]
    add_index :segment_memberships, :customer_id
    add_index :segment_memberships, :account_id

    # --- Drip campaign definition ---
    create_table :drip_campaigns do |t|
      t.bigint :account_id, null: false
      t.bigint :environment_id
      t.bigint :segment_id, null: false # the trigger segment
      t.string :name, null: false
      t.string :status, null: false, default: "draft" # draft|active|paused|archived
      t.boolean :allow_reentry, null: false, default: false
      t.boolean :exit_on_segment_leave, null: false, default: true
      t.timestamps
    end
    add_index :drip_campaigns, [:account_id, :status]
    add_index :drip_campaigns, :segment_id

    # --- Ordered steps within a drip ---
    create_table :drip_steps do |t|
      t.bigint :drip_campaign_id, null: false
      t.bigint :account_id, null: false
      t.bigint :template_id
      t.integer :position, null: false
      t.string :channel, null: false, default: "email"
      t.integer :delay_days, null: false, default: 0
      t.jsonb :conditions, default: {} # same DSL as Segment#conditions
      t.string :on_fail, null: false, default: "skip" # skip|exit
      t.timestamps
    end
    add_index :drip_steps, [:drip_campaign_id, :position], unique: true

    # --- Per-customer enrollment / run state ---
    create_table :drip_enrollments do |t|
      t.bigint :drip_campaign_id, null: false
      t.bigint :account_id, null: false
      t.bigint :customer_id, null: false
      t.bigint :segment_membership_id # entry that triggered this run
      t.string :status, null: false, default: "active" # active|completed|exited|canceled
      t.integer :current_position, null: false, default: 0
      t.datetime :anchor_at    # send-time of the last SENT step (delay anchor)
      t.datetime :next_run_at
      t.datetime :entered_at
      t.datetime :completed_at
      t.datetime :exited_at
      t.timestamps
    end
    add_index :drip_enrollments, [:drip_campaign_id, :customer_id]
    add_index :drip_enrollments, [:account_id, :status]
    add_index :drip_enrollments, :customer_id
    add_index :drip_enrollments, :next_run_at

    # --- Step execution history ---
    create_table :drip_step_executions do |t|
      t.bigint :drip_enrollment_id, null: false
      t.bigint :drip_step_id, null: false
      t.bigint :account_id, null: false
      t.bigint :message_id # transactional message created on send
      t.string :status, null: false # sent|skipped|suppressed|failed
      t.string :skip_reason
      t.datetime :scheduled_for
      t.datetime :evaluated_at
      t.datetime :sent_at
      t.timestamps
    end
    add_index :drip_step_executions, :drip_enrollment_id

    # --- Link transactional messages back to the drip that produced them ---
    add_column :messages, :drip_campaign_id, :bigint
    add_column :messages, :drip_step_id, :bigint
    add_index :messages, :drip_campaign_id

    # --- Allow account-level activities (segment enter/exit) with no environment ---
    change_column_null :customer_activities, :environment_id, true
  end
end
