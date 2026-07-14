# Configure Rack to handle larger request bodies for file uploads
# This allows base64-encoded file uploads up to 25MB through form submissions
# The main configuration is done in config/boot.rb via RACK_QUERY_PARSER_BYTESIZE_LIMIT

# Also set multipart limits if available
if defined?(Rack::Utils)
  Rack::Utils.multipart_total_part_limit = 0 if Rack::Utils.respond_to?(:multipart_total_part_limit=)
end

# Log the current limit to verify it's set correctly
Rails.logger.info "Rack Query Bytesize Limit: #{ENV['RACK_QUERY_PARSER_BYTESIZE_LIMIT']} bytes (#{ENV['RACK_QUERY_PARSER_BYTESIZE_LIMIT'].to_i / 1024 / 1024}MB)"