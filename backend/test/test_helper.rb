ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require "mocha/minitest"

module ActiveSupport
  class TestCase
    # Run tests sequentially to avoid PG connection issues
    parallelize(workers: 1)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Fix inflection: table name is chat_widget_settings but model is ChatWidgetSettings (not ChatWidgetSetting)
    set_fixture_class chat_widget_settings: ChatWidgetSettings

    # Add more helper methods to be used by all tests here...
    def widget_visitor_token
      "test_visitor_token_#{SecureRandom.hex(8)}"
    end
  end
end

module ActionDispatch
  class IntegrationTest
    # Generate a JWT token for the given user
    def jwt_for(user)
      JWT.encode({ id: user.id, exp: 24.hours.from_now.to_i }, Rails.application.secret_key_base)
    end

    # Set auth headers for JWT-based requests
    def auth_headers(user)
      { "Authorization" => "Bearer #{jwt_for(user)}" }
    end

    # Set auth headers for API key-based requests
    def api_key_headers(environment)
      { "Authorization" => "Bearer #{environment.api_key}" }
    end

    # Use HTTPS for all requests to avoid force_ssl redirects
    def get(path, **opts)    = super(path, **opts.merge(headers: (opts[:headers] || {}).merge("X-Forwarded-Proto" => "https")))
    def post(path, **opts)   = super(path, **opts.merge(headers: (opts[:headers] || {}).merge("X-Forwarded-Proto" => "https")))
    def patch(path, **opts)  = super(path, **opts.merge(headers: (opts[:headers] || {}).merge("X-Forwarded-Proto" => "https")))
    def put(path, **opts)    = super(path, **opts.merge(headers: (opts[:headers] || {}).merge("X-Forwarded-Proto" => "https")))
    def delete(path, **opts) = super(path, **opts.merge(headers: (opts[:headers] || {}).merge("X-Forwarded-Proto" => "https")))
  end
end
