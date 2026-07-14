class AddCleanupTrackingToSegments < ActiveRecord::Migration[8.0]
  def change
    add_column :segments, :cleanup_status, :string
    add_column :segments, :cleanup_progress, :integer, default: 0
    add_column :segments, :cleanup_total, :integer, default: 0
    add_column :segments, :cleanup_stats, :jsonb
    add_column :segments, :cleanup_started_at, :datetime
    add_column :segments, :cleanup_completed_at, :datetime
  end
end
