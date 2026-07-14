# Be sure to restart your server when you modify this file.

# Avoid CORS issues when API is called from the frontend app.
# Handle Cross-Origin Resource Sharing (CORS) in order to accept cross-origin Ajax requests.

# Read more: https://github.com/cyu/rack-cors
#

Rails.application.config.middleware.insert_before 0, Rack::Cors do
  # Frontend admin SPA
  allow do
    origins ENV['FRONTEND_URL']

    resource '*',
             headers: :any,
             methods: %i[get post put patch delete options head],
             credentials: true
  end

  # Marketing site contact / enterprise form. Static export on Cloudflare Pages,
  # so it posts here directly. No cookies, so no credentials. The local origins
  # let the dev site post at test-api; /contact is public and unauthenticated,
  # so an extra allowed origin grants nobody anything curl couldn't already do.
  allow do
    origins 'https://messy.sh', 'https://www.messy.sh',
            'https://messy-site.test', 'http://localhost:3004'

    resource '/contact',
             headers: :any,
             methods: %i[post options],
             credentials: false
  end

  # MCP server + OAuth discovery/token/registration. Reached by MCP clients
  # (Claude, OpenAI, Inspector) — bearer-token or PKCE, never cookies — so no
  # credentials. Open origin: these endpoints are protected by the token/PKCE
  # exchange itself, not by origin.
  allow do
    origins '*'

    resource '/mcp',
             headers: :any,
             methods: %i[get post options],
             credentials: false

    resource '/.well-known/*',
             headers: :any,
             methods: %i[get options],
             credentials: false

    resource '/oauth/*',
             headers: :any,
             methods: %i[get post options],
             credentials: false
  end

  # Embeddable chat widget (cross-domain, dynamic origin)
  allow do
    origins do |source, _env|
      true # Widget can be embedded on any domain; domain validation happens in WidgetAuthentication
    end

    resource '/widget/*',
             headers: :any,
             methods: %i[get post options],
             credentials: true

    resource '/cable',
             headers: :any,
             methods: %i[get post options],
             credentials: true
  end
end
