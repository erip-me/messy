# Shared plumbing for the unauthenticated OAuth callback controllers (mailbox +
# social). Both arrive from a provider redirect carrying a signed `state` JWT and
# an authorization `code`, then bounce the browser back to a frontend page.
module OauthCallback
  extend ActiveSupport::Concern

  private

  # Decodes the signed `state` JWT minted when the OAuth flow started. Returns the
  # payload hash, or nil if the token is missing/tampered.
  def oauth_state_payload
    JWT.decode(params[:state], Rails.application.secret_key_base, true, algorithm: "HS256").first
  rescue JWT::DecodeError
    nil
  end

  # Exchange the authorization code and merge the returned tokens into the
  # record's config. `mod` is the provider module (responds to #exchange_code).
  def store_oauth_tokens!(record, mod)
    record.update!(config: record.config.merge(mod.exchange_code(params[:code])))
  end

  # Redirect back to a frontend page (defaulting to the local dev host). `path`
  # may already carry a query string; extra keyword params are appended.
  def redirect_to_frontend(path, **query)
    base = "#{ENV['FRONTEND_URL'].presence || 'http://localhost:5173'}#{path}"
    separator = base.include?("?") ? "&" : "?"
    redirect_to "#{base}#{separator}#{query.to_query}", allow_other_host: true
  end
end
