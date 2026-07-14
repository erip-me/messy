# Brute-force / abuse protection. Throttles are per-IP and fail open (if the
# cache is unavailable, requests are allowed). Tune limits as traffic dictates.
class Rack::Attack
  # Use the Rails cache store for counters (Solid Cache / memory in dev).
  Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new unless Rails.env.production?

  # Identify the client behind the proxies. We sit behind Cloudflare, and the
  # NGINX ingress rewrites X-Forwarded-For to its own peer (a Cloudflare edge),
  # which rotates per request. Bucketing on that throttles nobody, so prefer
  # CF-Connecting-IP, which Cloudflare sets to the real client.
  #
  # ponytail: the header is trusted on faith. Anyone reaching the origin IP
  # directly can forge it and side-step every throttle below. Restrict the
  # ingress to Cloudflare's published ranges if that becomes a real risk.
  def self.client_ip(req)
    req.get_header("HTTP_CF_CONNECTING_IP").presence ||
      req.get_header("HTTP_X_FORWARDED_FOR")&.split(",")&.first&.strip ||
      req.ip
  end

  # Unauthenticated auth endpoints — the prime targets for enumeration/spam.
  throttle("magic_links/ip", limit: 10, period: 5.minutes) do |req|
    client_ip(req) if req.path == "/magic_links" && req.post?
  end

  throttle("magic_links/validate/ip", limit: 30, period: 5.minutes) do |req|
    client_ip(req) if req.path.start_with?("/magic_links/validate")
  end

  throttle("signup/ip", limit: 5, period: 1.hour) do |req|
    client_ip(req) if req.path == "/signup" && req.post?
  end

  # Public contact form. Each accepted request sends an email, so keep it tight.
  throttle("contact/ip", limit: 5, period: 1.hour) do |req|
    client_ip(req) if req.path == "/contact" && req.post?
  end

  # Public widget surface (visitor-token auth, reachable with the JS-embedded
  # widget key). Without throttling these allow mass customer/conversation
  # creation and email/job floods. Writes only; reads (config, unread) are cheap.
  WIDGET_WRITE_PATHS = [
    %r{\A/widget/v1/conversations\z},
    %r{\A/widget/v1/conversations/\d+/messages\z},
    %r{\A/widget/v1/offline\z},
    %r{\A/widget/v1/identify\z},
    %r{\A/customers/identify\z}
  ].freeze

  throttle("widget/ip", limit: 60, period: 1.minute) do |req|
    client_ip(req) if req.post? && WIDGET_WRITE_PATHS.any? { |re| re.match?(req.path) }
  end

  # MCP OAuth token endpoint — guards code/refresh brute-forcing.
  throttle("oauth_token/ip", limit: 30, period: 5.minutes) do |req|
    client_ip(req) if req.path == "/oauth/token" && req.post?
  end

  # MCP tool calls — per access token when present, else per IP. Generous; caps a
  # single agent hammering the in-process dispatch (each call is a sub-request).
  throttle("mcp/token", limit: 240, period: 1.minute) do |req|
    if req.path == "/mcp" && req.post?
      auth = req.get_header("HTTP_AUTHORIZATION")
      auth&.start_with?("Bearer ") ? Digest::SHA256.hexdigest(auth) : client_ip(req)
    end
  end

  self.throttled_responder = lambda do |_req|
    [429, { "Content-Type" => "application/json" },
     [{ error: "Too many requests. Please slow down and try again shortly." }.to_json]]
  end
end
