class SegmentResource
  include Alba::Resource

  attributes :id, :account_id, :name, :description, :conditions, :customer_count,
             :cleanup_status, :cleanup_progress, :cleanup_total, :cleanup_stats,
             :cleanup_started_at, :cleanup_completed_at, :created_at, :updated_at
end
