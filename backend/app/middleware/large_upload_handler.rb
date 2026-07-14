class LargeUploadHandler
  def initialize(app)
    @app = app
  end

  def call(env)
    # Check if this is a form submission that might contain file uploads
    if env["REQUEST_METHOD"] == "POST" && env["PATH_INFO"].match?(/\/api\//)

      # Get content length
      content_length = env["CONTENT_LENGTH"].to_i

      # If content is larger than 35MB, reject early with a user-friendly message
      max_size = 35 * 1024 * 1024
      if content_length > max_size
        # Return JSON error for API endpoints
        return [413,
                {
                  "Content-Type" => "application/json",
                  "Access-Control-Allow-Origin" => "*"
                },
                ['{"error": "File size exceeds maximum allowed size of 25MB. Please reduce file size and try again."}']]
      end

      # For large uploads, ensure we have the proper query parser limit
      env["rack.query_parser"] = Rack::QueryParser.new(Rack::QueryParser::Params, 35 * 1024 * 1024)
    end

    @app.call(env)
  rescue => e
    # Handle query limit errors (the exact exception class varies by Rack version)
    if e.message.include?("query size") && e.message.include?("exceeds limit")
      Rails.logger.error "Query limit exceeded: #{e.message}"

      # Return JSON error for API endpoints
      [413,
       {
         "Content-Type" => "application/json",
         "Access-Control-Allow-Origin" => "*"
       },
       ['{"error": "File upload too large. Please ensure your file is under 25MB."}']]
    else
      # Re-raise other exceptions
      raise e
    end
  end
end