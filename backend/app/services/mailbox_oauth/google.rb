module MailboxOauth
  # Central Google OAuth client shared by all Gmail mailboxes. Credentials come
  # from ENV (GOOGLE_OAUTH_CLIENT_ID / GOOGLE_OAUTH_CLIENT_SECRET), so customers
  # only consent — they never paste client secrets. Read-only Gmail scope: we
  # ingest mail here and send replies through the environment's SMTP/SES
  # integration, so no send scope is needed. gmail.readonly also covers watch().
  module Google
    extend OauthClient

    ENV_PREFIX = "GOOGLE_OAUTH".freeze
    SCOPES = ["https://www.googleapis.com/auth/gmail.readonly"].freeze
    AUTH_URI = "https://accounts.google.com/o/oauth2/v2/auth".freeze

    module_function

    def redirect_uri
      "#{ENV.fetch('API_URL')}/mailboxes/oauth/google/callback"
    end

    def authorize_url(state)
      "#{AUTH_URI}?" + {
        client_id: client_id,
        redirect_uri: redirect_uri,
        response_type: "code",
        scope: SCOPES.join(" "),
        access_type: "offline",
        include_granted_scopes: "true",
        prompt: "consent",
        state: state
      }.to_query
    end

    # Exchange an authorization code for tokens.
    # Returns the config fragment to merge into mailbox.config.
    def exchange_code(code)
      creds = ::Google::Auth::UserRefreshCredentials.new(
        client_id: client_id,
        client_secret: client_secret,
        scope: SCOPES,
        redirect_uri: redirect_uri,
        code: code
      )
      creds.fetch_access_token!
      {
        "access_token" => creds.access_token,
        "refresh_token" => creds.refresh_token,
        "token_expires_at" => creds.expires_at&.iso8601
      }.compact
    end
  end
end
