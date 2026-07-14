require 'csv'

class ProcessCsvImportJob < ApplicationJob
  queue_as :default

  PROGRESS_INTERVAL = 100

  def perform(import_id)
    import = CsvImport.find_by(id: import_id)
    return unless import && import.status == 'processing'

    # Stream rows instead of CSV.parse, which materializes every row up front.
    parsed = CSV.new(import.csv_content, headers: true)
    field_mapping = import.field_mapping
    dedup_strategy = import.dedup_strategy
    account = import.account
    row_errors = []
    success_count = 0
    failed_count = 0
    processed_rows = 0
    email_col = field_mapping.key('email')

    parsed.each_slice(PROGRESS_INTERVAL).with_index do |chunk, chunk_idx|
      # Extract emails for the chunk and batch-load existing customers
      chunk_emails = chunk.map { |row| row[email_col]&.strip&.downcase }.compact
      existing_by_email = account.customers.where(email: chunk_emails).index_by(&:email)

      chunk.each_with_index do |row, idx|
        begin
          row_num = (chunk_idx * PROGRESS_INTERVAL) + idx + 2
          email = row[email_col]&.strip&.downcase

          unless email.present? && email =~ URI::MailTo::EMAIL_REGEXP
            row_errors << { row: row_num, email: email, errors: ['Invalid or missing email'] }
            failed_count += 1
            processed_rows += 1
            next
          end

          attrs = {}
          custom_attrs = {}
          field_mapping.each do |col, field|
            next if field == 'skip' || field.blank?
            value = row[col]&.strip
            case field
            when 'email' then attrs[:email] = value&.downcase
            when 'first_name' then attrs[:first_name] = value
            when 'last_name' then attrs[:last_name] = value
            else
              if field.start_with?('custom:')
                attr_name = field.sub('custom:', '')
                custom_attrs[attr_name] = value
              end
            end
          end
          attrs[:custom_attributes] = custom_attrs if custom_attrs.any?

          existing = existing_by_email[email]
          if existing
            if dedup_strategy == 'update'
              # update! so a validation failure is recorded as a row error rather
              # than silently counted as a success.
              existing.update!(attrs)
              success_count += 1
            else
              failed_count += 1
              row_errors << { row: row_num, email: email, errors: ['Duplicate — skipped'] }
            end
          else
            new_customer = account.customers.create!(attrs)
            existing_by_email[email] = new_customer
            success_count += 1
          end

          processed_rows += 1
        rescue => e
          failed_count += 1
          row_errors << { row: row_num, email: email, errors: [e.message] }
          processed_rows += 1
        end
      end

      import.update_columns(processed_rows: processed_rows, success_count: success_count, failed_count: failed_count, row_errors: row_errors)
    end

    import.update_columns(status: 'completed', processed_rows: processed_rows, success_count: success_count, failed_count: failed_count, row_errors: row_errors)
  rescue => e
    import&.update_columns(status: 'failed')
  end
end
