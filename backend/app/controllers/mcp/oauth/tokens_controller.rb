module Mcp
  module Oauth
    # The token endpoint: exchanges an authorization code (with PKCE) or a refresh
    # token for a fresh access/refresh pair. Also handles revocation.
    class TokensController < BaseController
      # POST /oauth/token
      def create
        case params[:grant_type]
        when "authorization_code" then exchange_code
        when "refresh_token"      then exchange_refresh
        else
          render_oauth_error("unsupported_grant_type", "grant_type must be authorization_code or refresh_token")
        end
      end

      # POST /oauth/revoke (RFC 7009) — always 200, even for unknown tokens.
      def revoke
        raw = params[:token].to_s
        token = McpToken.find_by(token_digest: McpToken.digest(raw)) if raw.present?
        token&.revoke!
        head :ok
      end

      private

      def exchange_code
        code = McpAuthorizationCode.find_valid(params[:code])
        return render_oauth_error("invalid_grant", "Authorization code is invalid or expired") unless code

        grant = code.mcp_grant
        client = grant.mcp_client

        return render_oauth_error("invalid_client") unless client_authenticated?(client)
        return render_oauth_error("invalid_grant", "client mismatch") unless params[:client_id].to_s == client.client_id
        return render_oauth_error("invalid_grant", "redirect_uri mismatch") unless params[:redirect_uri].to_s == code.redirect_uri

        unless Mcp::Oauth::Pkce.verify(params[:code_verifier], code.code_challenge, code.code_challenge_method)
          return render_oauth_error("invalid_grant", "PKCE verification failed")
        end

        code.consume!
        issue_tokens(grant)
      end

      def exchange_refresh
        refresh = McpToken.authenticate(params[:refresh_token], kind: :refresh)
        return render_oauth_error("invalid_grant", "Refresh token is invalid or expired") unless refresh

        grant = refresh.mcp_grant
        return render_oauth_error("invalid_client") unless client_authenticated?(grant.mcp_client)
        return render_oauth_error("invalid_grant", "Connection is disabled") unless grant.enabled?

        # Rotate: the presented refresh token is single-use.
        refresh.revoke!
        issue_tokens(grant)
      end

      def issue_tokens(grant)
        access, raw_access = McpToken.issue!(grant: grant, kind: :access)
        _refresh, raw_refresh = McpToken.issue!(grant: grant, kind: :refresh)
        grant.touch_used!

        render json: {
          access_token: raw_access,
          token_type: "Bearer",
          expires_in: (access.expires_at - Time.current).to_i,
          refresh_token: raw_refresh,
          scope: grant.scopes.join(" ")
        }
      end

      # Public (PKCE) clients need no secret. Confidential clients must present a
      # matching secret via client_secret_post or HTTP Basic.
      def client_authenticated?(client)
        return true if client.token_endpoint_auth_method == "none" && client.client_secret_digest.blank?

        secret = params[:client_secret].presence || basic_auth_secret
        client.secret_matches?(secret)
      end

      def basic_auth_secret
        ActionController::HttpAuthentication::Basic.decode_credentials(request.authorization).to_s.split(":", 2).last
      rescue StandardError
        nil
      end
    end
  end
end
