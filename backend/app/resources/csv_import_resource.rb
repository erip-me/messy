# csv_content (the raw uploaded file) stays server-side.
class CsvImportResource
  include Alba::Resource

  attributes :id, :account_id, :user_id, :field_mapping, :dedup_strategy,
             :status, :total_rows, :processed_rows, :success_count,
             :failed_count, :row_errors, :created_at, :updated_at
end
