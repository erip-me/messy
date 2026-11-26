# Error and performance reporting through any Sentry-protocol endpoint (Pushleft's
# Errors page in production). Off without SENTRY_DSN: development, tests, self-hosts.
# The SDK reads SENTRY_RELEASE and SENTRY_ENVIRONMENT from the env; the environment
# defaults to Rails.env.

# Paths carry secrets (tracking and unsubscribe tokens, webhook url hashes, magic
# links), and so can query strings. Long token-like path segments and every query
# value leave as [filtered].
module SentryScrub
  SEGMENT = %r{/[A-Za-z0-9_-]{20,}(?=[/?#.]|\z)}

  def self.url(value)
    value&.gsub(SEGMENT, "/[filtered]")&.sub(/\?.*\z/, "?[filtered]")
  end

  def self.event(event, _hint = nil)
    if (request = event.request)
      request.url = url(request.url)
      request.query_string = "[filtered]" if request.query_string.present?
    end
    event
  end
end

if ENV["SENTRY_DSN"].present?
  Sentry.init do |config|
    config.dsn = ENV["SENTRY_DSN"]
    config.traces_sample_rate = 0.1
    config.before_send = SentryScrub.method(:event)
    config.before_send_transaction = SentryScrub.method(:event)
  end
end
