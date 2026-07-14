module Mcp
  # The MCP Streamable-HTTP endpoint (POST /mcp): a JSON-RPC 2.0 handler over the
  # tool catalog. Responds application/json by default and text/event-stream when
  # the client only accepts SSE. Long-lived server→client streaming lives in
  # StreamController (GET /mcp).
  class ServerController < ApplicationController
    include McpTokenAuthentication

    PROTOCOL_VERSION = "2025-06-18".freeze
    SUPPORTED_PROTOCOLS = %w[2024-11-05 2025-03-26 2025-06-18].freeze

    # POST /mcp
    def handle
      return unless require_mcp_token!

      message = request_json
      if message.is_a?(Array)
        responses = message.filter_map { |m| dispatch_message(m) }
        return head(:accepted) if responses.empty?
        render_jsonrpc(responses)
      else
        response_body = dispatch_message(message)
        return head(:accepted) if response_body.nil? # notification
        render_jsonrpc(response_body)
      end
    end

    private

    # Returns a JSON-RPC response hash, or nil for notifications (no reply).
    def dispatch_message(message)
      return nil unless message.is_a?(Hash)
      id = message["id"]
      method = message["method"]

      # Notifications carry no id and expect no response.
      return nil if id.nil? && method.to_s.start_with?("notifications/")

      case method
      when "initialize"       then success(id, initialize_result(message))
      when "ping"             then success(id, {})
      when "tools/list"       then success(id, tools_list_result)
      when "tools/call"       then tools_call_result(id, message["params"] || {})
      when "notifications/initialized" then nil
      else
        error(id, -32601, "Method not found: #{method}")
      end
    rescue StandardError => e
      # Never let an exception escape into ApplicationController's HTML-500
      # handler — that would break the JSON-RPC envelope and surface to the agent
      # as an opaque transport error. Return a well-formed JSON-RPC error instead.
      Rails.logger.error("[MCP] #{message.is_a?(Hash) ? message["method"] : "?"} raised: #{e.class}: #{e.message}")
      error(message.is_a?(Hash) ? message["id"] : nil, -32603, "Internal error: #{e.message}")
    end

    def initialize_result(message)
      requested = message.dig("params", "protocolVersion")
      version = SUPPORTED_PROTOCOLS.include?(requested) ? requested : PROTOCOL_VERSION
      {
        protocolVersion: version,
        capabilities: { tools: { listChanged: false } },
        serverInfo: { name: "Messy", version: "1.0.0" }
      }
    end

    def tools_list_result
      tools = ToolRegistry.visible_to(
        scopes: current_mcp_grant.scopes,
        admin: current_mcp_grant.user.account_admin?
      )
      { tools: tools.map(&:definition) }
    end

    def tools_call_result(id, params)
      grant = current_mcp_grant
      name = params["name"]
      arguments = params["arguments"] || {}
      tool = ToolRegistry.find(name)

      return tool_error(id, name, arguments, "Unknown tool: #{name}", status: :rejected) unless tool

      unless grant.enabled?
        return tool_error(id, name, arguments,
                          "MCP access is disabled for this connection. An account admin can enable it, or re-enable this connection, under Settings → MCP Server.",
                          status: :rejected)
      end

      unless tool_visible?(tool, grant)
        return tool_error(id, name, arguments, "This connection is not authorized for tool: #{name}", status: :rejected)
      end

      started = current_monotonic
      result = dispatcher(grant).call(tool, arguments)
      duration = ((current_monotonic - started) * 1000).round

      log_call(grant: grant, tool_name: name, arguments: arguments,
               status: result.success? ? :ok : :error, http_status: result.status, duration_ms: duration,
               error_message: result.success? ? nil : truncate_error(result.body))

      current_mcp_access_token.touch_used!
      grant.touch_used!

      text = if result.success?
               json_text(result.body)
             else
               # Make failures legible to the agent: the HTTP status plus the
               # controller's own error body (e.g. a 422 validation message).
               "Tool call failed (HTTP #{result.status}): #{truncate_error(result.body)}"
             end
      success(id, {
        content: [{ type: "text", text: text }],
        isError: !result.success?
      })
    end

    def tool_visible?(tool, grant)
      grant.scopes.include?(tool.scope) && (grant.user.account_admin? || !tool.admin?)
    end

    def dispatcher(grant)
      Mcp::RestDispatcher.new(grant, host: request.host, ssl: request.ssl?)
    end

    # ── JSON-RPC envelopes ────────────────────────────────────────────────────
    def success(id, result)
      { jsonrpc: "2.0", id: id, result: result }
    end

    def error(id, code, message)
      { jsonrpc: "2.0", id: id, error: { code: code, message: message } }
    end

    # Gate/auth rejections that block a call before dispatch. Returned as an
    # isError tool result (not a JSON-RPC error) so the reason reaches the agent:
    # remote MCP clients surface result content but collapse a JSON-RPC error into
    # a generic "error occurred during tool execution" message that hides why.
    def tool_error(id, name, arguments, message, status:)
      log_call(grant: current_mcp_grant, tool_name: name, arguments: arguments,
               status: status, http_status: nil, duration_ms: 0, error_message: message)
      success(id, { content: [{ type: "text", text: message }], isError: true })
    end

    def log_call(grant:, tool_name:, arguments:, status:, http_status:, duration_ms:, error_message:)
      McpRequestLog.create!(
        account_id: grant&.account_id,
        mcp_grant_id: grant&.id,
        user_id: grant&.user_id,
        environment_id: grant&.environment_id,
        tool_name: tool_name,
        jsonrpc_method: "tools/call",
        arguments: filtered_arguments(arguments),
        status: status,
        http_status: http_status,
        duration_ms: duration_ms,
        error_message: error_message&.first(500)
      )
    rescue StandardError => e
      Rails.logger.error("[MCP] failed to write request log: #{e.message}")
    end

    def filtered_arguments(arguments)
      parameter_filter.filter(arguments.to_h)
    rescue StandardError
      {}
    end

    def parameter_filter
      @parameter_filter ||= ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters)
    end

    def truncate_error(body)
      msg = body.is_a?(Hash) ? (body["error"] || body["errors"]) : body
      Array(msg).join(", ").presence || "Tool call failed"
    end

    def json_text(body)
      body.is_a?(String) ? body : JSON.generate(body)
    end

    # ── transport ─────────────────────────────────────────────────────────────
    def request_json
      raw = request.body.read
      raw.present? ? JSON.parse(raw) : {}
    rescue JSON::ParserError
      {}
    end

    def render_jsonrpc(payload)
      if prefer_sse?
        render plain: "event: message\ndata: #{JSON.generate(payload)}\n\n", content_type: "text/event-stream"
      else
        render json: payload
      end
    end

    # Only stream when the client explicitly cannot take JSON.
    def prefer_sse?
      accept = request.headers["Accept"].to_s
      accept.include?("text/event-stream") && !accept.include?("application/json")
    end

    def current_monotonic
      Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end
  end
end
