module SocialOauth
  # Central LinkedIn OAuth app shared by all LinkedIn social integrations.
  # Credentials come from ENV (LINKEDIN_OAUTH_CLIENT_ID /
  # LINKEDIN_OAUTH_CLIENT_SECRET), so operators only consent — they never paste a
  # client secret. Scopes cover organization page publishing: read + write the
  # org's shares and read which organizations the member administers (to populate
  # the region's page dropdown). Requires the "Community Management API" product
  # to be approved on the LinkedIn app.
  #
  # LinkedIn access tokens live ~60 days; a refresh token (available once the app
  # is approved) is returned alongside and lives ~365 days, so the publisher
  # refreshes on demand rather than forcing a reconnect.
  module Linkedin
    extend OauthClient
    extend OauthClient::TokenExchange

    ENV_PREFIX = "LINKEDIN_OAUTH".freeze
    PROVIDER_LABEL = "LinkedIn".freeze
    SCOPES = %w[r_organization_social w_organization_social rw_organization_admin].freeze
    AUTH_URI = "https://www.linkedin.com/oauth/v2/authorization".freeze
    TOKEN_URI = "https://www.linkedin.com/oauth/v2/accessToken".freeze

    module_function

    def redirect_uri
      "#{ENV.fetch('API_URL')}/social/oauth/linkedin/callback"
    end

    def authorize_url(state)
      "#{AUTH_URI}?" + {
        response_type: "code",
        client_id: client_id,
        redirect_uri: redirect_uri,
        scope: SCOPES.join(" "),
        state: state
      }.to_query
    end

    def token_endpoint
      TOKEN_URI
    end
  end
end
