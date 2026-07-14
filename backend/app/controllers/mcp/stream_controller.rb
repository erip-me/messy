module Mcp
  # GET /mcp — the Streamable-HTTP server→client channel. Opens an SSE stream a
  # connected agent can hold open to receive server-initiated messages (e.g. live
  # activity notifications). v1 establishes the stream and keeps it alive; pushing
  # domain events onto it is an additive change. Reuses ActionController::Live,
  # mirroring email_finder_controller.
  #
  # NOTE: an open SSE connection holds a Puma thread for its lifetime. This is
  # opt-in (only when a client GETs /mcp); if many long-lived streams are needed,
  # move this to a dedicated process rather than the shared web pool.
  class StreamController < ApplicationController
    include ActionController::Live
    include McpTokenAuthentication

    KEEPALIVE_SECONDS = 25

    def show
      return unless require_mcp_token!
      return unless current_mcp_grant.enabled?

      response.headers["Content-Type"] = "text/event-stream"
      response.headers["Cache-Control"] = "no-cache"
      response.headers["X-Accel-Buffering"] = "no" # disable nginx proxy buffering

      sse = ActionController::Live::SSE.new(response.stream, retry: 3000)
      sse.write({ ready: true }, event: "connected")

      loop do
        sse.write({ ts: Time.current.to_i }, event: "ping")
        sleep KEEPALIVE_SECONDS
      end
    rescue ActionController::Live::ClientDisconnected, IOError
      # Client went away — nothing to do.
    ensure
      sse&.close
    end
  end
end
