module Mcp
  module Oauth
    # Dynamic Client Registration (RFC 7591). MCP clients self-register before any
    # user has authenticated; tenant identity is bound later at consent.
    class RegistrationsController < BaseController
      # POST /oauth/register
      def create
        redirect_uris = Array(params[:redirect_uris]).map(&:to_s).reject(&:blank?)
        if redirect_uris.empty?
          return render_oauth_error("invalid_redirect_uri", "redirect_uris is required")
        end

        auth_method = params[:token_endpoint_auth_method].presence || "none"
        grant_types = Array(params[:grant_types]).presence || %w[authorization_code refresh_token]

        client, secret = McpClient.register!(
          name: params[:client_name],
          redirect_uris: redirect_uris,
          token_endpoint_auth_method: auth_method,
          grant_types: grant_types
        )

        body = {
          client_id: client.client_id,
          client_id_issued_at: client.created_at.to_i,
          client_name: client.name,
          redirect_uris: client.redirect_uris,
          grant_types: client.grant_types,
          token_endpoint_auth_method: client.token_endpoint_auth_method
        }
        if secret
          body[:client_secret] = secret
          body[:client_secret_expires_at] = 0 # never expires
        end

        render json: body, status: :created
      end
    end
  end
end
