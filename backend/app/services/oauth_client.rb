# Shared OAuth client boilerplate for the central provider apps (Gmail,
# Office365, LinkedIn). A provider module `extend`s this and declares its
# `ENV_PREFIX`; the three credential helpers then read
# `<PREFIX>_CLIENT_ID` / `<PREFIX>_CLIENT_SECRET` from ENV. Provider-specific URL
# shaping (authorize URL, redirect URI, token exchange) stays in the provider.
module OauthClient
  def configured?
    ENV["#{self::ENV_PREFIX}_CLIENT_ID"].present? && ENV["#{self::ENV_PREFIX}_CLIENT_SECRET"].present?
  end

  def client_id
    ENV.fetch("#{self::ENV_PREFIX}_CLIENT_ID")
  end

  def client_secret
    ENV.fetch("#{self::ENV_PREFIX}_CLIENT_SECRET")
  end
end
