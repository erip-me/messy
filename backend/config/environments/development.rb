require "active_support/core_ext/integer/time"

Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # In the development environment your application's code is reloaded any time
  # it changes. This slows down response time but is perfect for development
  # since you don't have to restart the web server when you make code changes.
  config.enable_reloading = true

  # Do not eager load code on boot.
  config.eager_load = false

  # Return JSON errors instead of HTML debug pages (API-only app).
  config.consider_all_requests_local = false

  # Enable server timing
  config.server_timing = true

  config.logger = ActiveSupport::Logger.new(STDOUT)
    .tap  { |logger| logger.formatter = ::Logger::Formatter.new }
    .then { |logger| ActiveSupport::TaggedLogging.new(logger) }

  # Enable/disable caching. By default caching is disabled.
  # Run rails dev:cache to toggle caching.
  if Rails.root.join("tmp/caching-dev.txt").exist?
    config.cache_store = :memory_store
    config.public_file_server.headers = {
      "Cache-Control" => "public, max-age=#{2.days.to_i}"
    }
  else
    config.action_controller.perform_caching = false

    config.cache_store = :null_store
  end

  # Store uploaded files on the local file system (see config/storage.yml for options).
  config.active_storage.service = :local

  # email setup
  config.action_mailer.raise_delivery_errors = true
  config.action_mailer.delivery_method = :ses

  config.action_mailer.perform_caching = false

  # Print deprecation notices to the Rails logger.
  config.active_support.deprecation = :log

  # Raise exceptions for disallowed deprecations.
  config.active_support.disallowed_deprecation = :raise

  # Tell Active Support which deprecation messages to disallow.
  config.active_support.disallowed_deprecation_warnings = []

  # Raise an error on page load if there are pending migrations.
  config.active_record.migration_error = :page_load

  # Highlight code that triggered database queries in logs.
  config.active_record.verbose_query_logs = true

  # Highlight code that enqueued background job in logs.
  config.active_job.verbose_enqueue_logs = true


  # Raises error for missing translations.
  # config.i18n.raise_on_missing_translations = true

  # Annotate rendered view with file names.
  # config.action_view.annotate_rendered_view_with_filenames = true

  # Uncomment if you wish to allow Action Cable access from any origin.
  # config.action_cable.disable_request_forgery_protection = true

  # Raise error when a before_action's only/except options reference missing actions
  config.action_controller.raise_on_missing_callback_actions = true

  config.hosts.clear


  frontend_url = ENV.fetch('FRONTEND_URL', 'http://localhost:5173')
  api_url = ENV.fetch('API_URL', 'http://localhost:3300')

  api_uri = URI.parse(api_url)
  cable_protocol = api_uri.scheme == 'https' ? 'wss' : 'ws'
  config.action_cable.url = "#{cable_protocol}://#{api_uri.host}:#{api_uri.port}/cable"
  config.action_cable.allowed_request_origins = [/https?:\/\/.*/]

  Rails.application.routes.default_url_options[:host] = api_uri.host
  Rails.application.routes.default_url_options[:port] = api_uri.port
  Rails.application.routes.default_url_options[:protocol] = api_uri.scheme
  config.action_mailer.default_url_options = { host: api_uri.host, port: api_uri.port }

end
