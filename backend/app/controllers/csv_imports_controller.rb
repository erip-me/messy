require 'csv'

class CsvImportsController < ApplicationController
  before_action :authenticate_user!

  MAX_FILE_SIZE = 10 * 1024 * 1024 # 10MB

  # POST /csv_imports/upload
  def upload
    file = params[:file]
    return render json: { error: 'No file provided' }, status: :bad_request unless file
    return render json: { error: 'File must be a CSV' }, status: :bad_request unless file.content_type.in?(['text/csv', 'application/vnd.ms-excel', 'text/plain']) || file.original_filename.end_with?('.csv')
    return render json: { error: 'File too large (max 10MB)' }, status: :bad_request if file.size > MAX_FILE_SIZE

    csv_content = file.read.force_encoding('UTF-8')
    parsed = CSV.parse(csv_content, headers: true)
    headers = parsed.headers.compact
    preview_rows = parsed.first(10).map(&:to_h)

    import = current_user.account.csv_imports.create!(
      user: current_user,
      csv_content: csv_content,
      total_rows: parsed.length,
      status: 'pending'
    )

    render json: {
      import_id: import.id,
      headers: headers,
      preview_rows: preview_rows,
      total_rows: parsed.length
    }
  rescue CSV::MalformedCSVError => e
    render json: { error: "Invalid CSV: #{e.message}" }, status: :bad_request
  end

  # POST /csv_imports/:id/validate
  def validate
    import = current_user.account.csv_imports.find(params[:id])
    field_mapping = params[:field_mapping].is_a?(ActionController::Parameters) ? params[:field_mapping].permit(params[:field_mapping].keys).to_h : {}

    return render json: { error: 'Email mapping is required' }, status: :bad_request unless field_mapping.values.include?('email')

    parsed = CSV.parse(import.csv_content, headers: true)
    errors = []
    valid_count = 0

    parsed.each_with_index do |row, idx|
      row_num = idx + 2
      row_errors = []
      email_col = field_mapping.key('email')
      email = row[email_col]&.strip

      if email.blank?
        row_errors << 'Email is required'
      elsif email !~ URI::MailTo::EMAIL_REGEXP
        row_errors << "Invalid email format: #{email}"
      end

      if row_errors.any?
        errors << { row: row_num, email: email, errors: row_errors }
      else
        valid_count += 1
      end
    end

    render json: {
      total_rows: parsed.length,
      valid_count: valid_count,
      error_count: errors.length,
      errors: errors.first(50)
    }
  end

  # POST /csv_imports/:id/start
  def start
    import = current_user.account.csv_imports.find(params[:id])
    return render json: { error: 'Import already started' }, status: :bad_request unless import.status == 'pending'

    field_mapping = params[:field_mapping].is_a?(ActionController::Parameters) ? params[:field_mapping].permit(params[:field_mapping].keys).to_h : {}
    dedup_strategy = params[:dedup_strategy] || 'skip'

    return render json: { error: 'Email mapping is required' }, status: :bad_request unless field_mapping.values.include?('email')
    return render json: { error: 'Invalid dedup strategy' }, status: :bad_request unless CsvImport::DEDUP_STRATEGIES.include?(dedup_strategy)

    import.update!(field_mapping: field_mapping, dedup_strategy: dedup_strategy, status: 'processing')
    ProcessCsvImportJob.perform_later(import.id)

    render json: CsvImportResource.new(import).serialize
  end

  # GET /csv_imports/:id
  def show
    import = current_user.account.csv_imports.find(params[:id])
    render json: CsvImportResource.new(import).serialize
  end

  # GET /csv_imports
  def index
    imports = current_user.account.csv_imports.order(created_at: :desc).limit(20)
    render json: CsvImportResource.new(imports).serialize
  end
end
