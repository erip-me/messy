module Mcp
  module Oauth
    # Shared helpers for the OAuth 2.1 authorization-server endpoints. These are
    # public (no api-key / operator gates); each action authenticates as needed
    # (the consent action requires a dashboard user, the token endpoint uses PKCE
    # / client auth).
    class BaseController < ApplicationController
      private

      # Absolute base URL of this authorization server / API, honouring the proxy
      # (ingress terminates TLS and forwards the original host).
      def mcp_base_url
        request.base_url
      end

      # The protected MCP resource identifier advertised in discovery + 401s.
      def mcp_resource_url
        "#{mcp_base_url}/mcp"
      end

      def frontend_url
        ENV["FRONTEND_URL"].presence || mcp_base_url
      end

      def find_client(client_id)
        McpClient.find_by(client_id: client_id)
      end

      # OAuth error envelope (RFC 6749 §5.2).
      def render_oauth_error(error, description = nil, status: :bad_request)
        body = { error: error }
        body[:error_description] = description if description
        render json: body, status: status
      end

      # Builds "redirect_uri?key=val&..." preserving any existing query.
      def redirect_with(uri, params)
        parsed = URI.parse(uri)
        existing = URI.decode_www_form(parsed.query || "")
        merged = existing + params.compact.map { |k, v| [k.to_s, v.to_s] }
        parsed.query = URI.encode_www_form(merged)
        parsed.to_s
      end
    end
  end
end
