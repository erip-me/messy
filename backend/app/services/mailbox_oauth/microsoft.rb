module MailboxOauth
  # Central Microsoft (Entra) OAuth app shared by all Office365 mailboxes.
  # Delegated Graph scopes: Mail.Read (read + subscribe to the inbox),
  # offline_access (refresh token), and sign-in scopes to identify the mailbox.
  # Tenant defaults to "common" (any org + personal Microsoft accounts).
  module Microsoft
    extend OauthClient
    extend OauthClient::TokenExchange

    ENV_PREFIX = "MS_OAUTH".freeze
    PROVIDER_LABEL = "Microsoft".freeze
    SCOPES = %w[offline_access openid email profile User.Read Mail.Read].freeze

    module_function

    def tenant
      ENV["MS_OAUTH_TENANT"].presence || "common"
    end

    def redirect_uri
      "#{ENV.fetch('API_URL')}/mailboxes/oauth/microsoft/callback"
    end

    def authorize_url(state)
      "https://login.microsoftonline.com/#{tenant}/oauth2/v2.0/authorize?" + {
        client_id: client_id,
        response_type: "code",
        redirect_uri: redirect_uri,
        response_mode: "query",
        scope: SCOPES.join(" "),
        state: state
      }.to_query
    end

    def token_endpoint
      "https://login.microsoftonline.com/#{tenant}/oauth2/v2.0/token"
    end

    # Microsoft requires the scope on the token request too; it may omit a fresh
    # refresh_token on refresh, in which case callers keep the old one.
    def token_request_extras
      { scope: SCOPES.join(" ") }
    end
  end
end
