module Mcp
  # Executes a tool by replaying it as an in-process request against the app's own
  # REST routes. It mints a short-lived JWT for the grant's user and injects the
  # chosen environment, so every existing controller authenticates and authorizes
  # exactly as it would for that user in the dashboard — no controller is special-
  # cased for MCP. This reuses rule evaluation, Liquid rendering, Solid Queue
  # enqueues and cross-account guards verbatim.
  class RestDispatcher
    Result = Struct.new(:status, :body, :success, keyword_init: true) do
      def success?
        success
      end
    end

    # The internal JWT is only ever consumed by the sub-request below and never
    # leaves the process; a tight expiry bounds any theoretical misuse.
    INTERNAL_JWT_TTL = 2.minutes

    def initialize(grant, host:, ssl:)
      @grant = grant
      @host = host
      @ssl = ssl
    end

    def call(tool, args)
      args = (args || {}).transform_keys(&:to_s)
      session = ActionDispatch::Integration::Session.new(Rails.application)
      session.https! if @ssl

      path = build_path(tool, args)
      headers = {
        "HTTP_AUTHORIZATION" => "Bearer #{internal_jwt}",
        "HTTP_X_ENVIRONMENT_ID" => @grant.environment_id.to_s,
        "HTTP_HOST" => @host
      }

      if tool.http_method == :get
        qs = query_string(tool, args)
        full = qs.present? ? "#{path}?#{qs}" : path
        session.get(full, headers: headers)
      else
        session.public_send(tool.http_method, path, params: build_body(tool, args), headers: headers, as: :json)
      end

      parse(session.response)
    rescue StandardError => e
      Rails.logger.error("[MCP dispatch] #{tool.name}: #{e.class}: #{e.message}")
      Result.new(status: 500, body: { "error" => "Tool dispatch failed" }, success: false)
    end

    private

    def internal_jwt
      JWT.encode(
        { id: @grant.user_id, exp: INTERNAL_JWT_TTL.from_now.to_i },
        Rails.application.secret_key_base,
        "HS256"
      )
    end

    def build_path(tool, args)
      tool.path.gsub(/\{(\w+)\}/) { |_m| CGI.escape(args[Regexp.last_match(1)].to_s) }
    end

    def query_string(tool, args)
      keys = tool.http_method == :get ? (args.keys - tool.path_keys) : tool.query_keys
      pairs = keys.filter_map do |k|
        v = args[k.to_s]
        [k.to_s, v] unless v.nil?
      end
      URI.encode_www_form(pairs)
    end

    def build_body(tool, args)
      consumed = tool.path_keys.map(&:to_s) + tool.query_keys.map(&:to_s)
      body = args.except(*consumed)
      tool.body_key ? { tool.body_key.to_s => body } : body
    end

    def parse(response)
      parsed = begin
        response.body.present? ? JSON.parse(response.body) : {}
      rescue JSON::ParserError
        response.body
      end
      Result.new(status: response.status, body: parsed, success: response.status.between?(200, 299))
    end
  end
end
