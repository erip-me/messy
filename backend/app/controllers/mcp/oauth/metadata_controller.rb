module Mcp
  module Oauth
    # OAuth/MCP discovery documents. Public, cacheable. Clients (Claude, OpenAI,
    # MCP Inspector) fetch these to learn how to authorize.
    class MetadataController < BaseController
      # GET /.well-known/oauth-authorization-server (RFC 8414)
      def authorization_server
        render json: {
          issuer: mcp_base_url,
          authorization_endpoint: "#{mcp_base_url}/oauth/authorize",
          token_endpoint: "#{mcp_base_url}/oauth/token",
          registration_endpoint: "#{mcp_base_url}/oauth/register",
          revocation_endpoint: "#{mcp_base_url}/oauth/revoke",
          scopes_supported: Mcp::Scopes.supported,
          response_types_supported: ["code"],
          grant_types_supported: %w[authorization_code refresh_token],
          code_challenge_methods_supported: ["S256"],
          token_endpoint_auth_methods_supported: %w[none client_secret_post client_secret_basic]
        }
      end

      # GET /.well-known/oauth-protected-resource (RFC 9728) — points MCP clients
      # at the authorization server that guards the /mcp resource.
      def protected_resource
        render json: {
          resource: mcp_resource_url,
          authorization_servers: [mcp_base_url],
          scopes_supported: Mcp::Scopes.supported,
          bearer_methods_supported: ["header"]
        }
      end
    end
  end
end
