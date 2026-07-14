module OauthClient
  # Faraday-based OAuth2 token exchange shared by the providers that POST to a
  # plain token endpoint (Microsoft, LinkedIn). Google uses the google-auth SDK
  # instead and does NOT mix this in. The host provider supplies `#token_endpoint`,
  # `#redirect_uri`, a `PROVIDER_LABEL` constant, and optionally overrides
  # `#token_request_extras` (extra body params, e.g. Microsoft's scope).
  module TokenExchange
    def exchange_code(code)
      request_token(grant_type: "authorization_code", code: code, redirect_uri: redirect_uri)
    end

    def refresh(refresh_token)
      request_token(grant_type: "refresh_token", refresh_token: refresh_token)
    end

    def request_token(**params)
      resp = Faraday.post(token_endpoint) do |req|
        req.headers["Content-Type"] = "application/x-www-form-urlencoded"
        req.body = URI.encode_www_form(
          params.merge(client_id: client_id, client_secret: client_secret).merge(token_request_extras)
        )
      end
      raise "#{self::PROVIDER_LABEL} token request failed: #{resp.status} #{resp.body}" unless resp.success?

      data = JSON.parse(resp.body)
      {
        "access_token" => data["access_token"],
        "refresh_token" => data["refresh_token"],
        "token_expires_at" => (Time.current + data["expires_in"].to_i.seconds).iso8601
      }.compact
    end

    # Extra params merged into the token-request body. Default: none.
    def token_request_extras
      {}
    end
  end
end
