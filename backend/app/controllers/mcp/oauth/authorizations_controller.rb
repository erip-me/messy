module Mcp
  module Oauth
    # The authorization endpoint. Two actions:
    #   GET  /oauth/authorize  — validate the request, then bounce the browser to
    #                            the SPA consent screen (no auth here).
    #   POST /oauth/authorize  — the consent decision, called by the SPA with the
    #                            dashboard JWT. Issues the auth code (or a denial
    #                            redirect) and returns the URL to send the browser.
    class AuthorizationsController < BaseController
      # GET /oauth/authorize
      def new
        client = find_client(params[:client_id])
        return render_oauth_error("invalid_client", "Unknown client_id") unless client

        redirect_uri = params[:redirect_uri].to_s
        unless client.redirect_uri_allowed?(redirect_uri)
          # Never redirect to an unregistered URI — render the error instead.
          return render_oauth_error("invalid_redirect_uri", "redirect_uri is not registered for this client")
        end

        # Errors past this point are safe to hand back to the client via redirect.
        if params[:response_type].to_s != "code"
          return redirect_to redirect_with(redirect_uri, error: "unsupported_response_type", state: params[:state]), allow_other_host: true
        end
        if params[:code_challenge].blank? || params[:code_challenge_method].to_s != "S256"
          return redirect_to redirect_with(redirect_uri, error: "invalid_request", error_description: "PKCE S256 required", state: params[:state]), allow_other_host: true
        end

        # Hand the (validated) request to the SPA consent page verbatim.
        consent_params = params.permit(
          :client_id, :redirect_uri, :response_type, :scope, :state,
          :code_challenge, :code_challenge_method, :resource
        ).to_h
        redirect_to "#{frontend_url}/oauth/consent?#{consent_params.to_query}", allow_other_host: true
      end

      # POST /oauth/authorize — the consent decision (JWT-authenticated SPA call).
      def create
        return render json: { error: "Not authorized" }, status: :unauthorized unless current_user

        client = find_client(params[:client_id])
        return render_oauth_error("invalid_client", "Unknown client_id") unless client

        redirect_uri = params[:redirect_uri].to_s
        unless client.redirect_uri_allowed?(redirect_uri)
          return render_oauth_error("invalid_redirect_uri", "redirect_uri is not registered for this client")
        end

        unless ActiveModel::Type::Boolean.new.cast(params[:approved])
          return render json: { redirect_to: redirect_with(redirect_uri, error: "access_denied", state: params[:state]) }
        end

        environment = current_user.account.environments.find_by(id: params[:environment_id])
        return render_oauth_error("invalid_request", "A valid environment must be selected") unless environment

        scopes = Mcp::Scopes.parse(params[:scope])

        grant = McpGrant.active.find_or_initialize_by(
          account: current_user.account,
          user: current_user,
          mcp_client: client,
          environment: environment
        )
        grant.scopes = scopes
        grant.revoked_at = nil
        grant.save!

        raw_code = McpAuthorizationCode.issue!(
          grant: grant,
          redirect_uri: redirect_uri,
          code_challenge: params[:code_challenge],
          code_challenge_method: params[:code_challenge_method].presence || "S256"
        )

        render json: { redirect_to: redirect_with(redirect_uri, code: raw_code, state: params[:state]) }
      end
    end
  end
end
