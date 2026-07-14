require_relative "boot"
require 'resolv-replace'

require 'dotenv/load'
require "rails/all"

Bundler.require(*Rails.groups)

module Messy
  class Application < Rails::Application
    config.load_defaults 8.0

    config.middleware.use ActionDispatch::Cookies
    config.middleware.use ActionDispatch::Session::CookieStore,
                          key: '_messy_session',
                          same_site: :None,
                          secure: true,
                          http_only: true,
                          expire_after: 24.hours

    config.autoload_lib(ignore: %w(assets tasks))

    config.generators do |g|
      g.test_framework nil # Disable all test generation
    end

    config.autoload_paths += %W(
      #{config.root}/app/models/rules
      #{config.root}/app/models/messages
      #{config.root}/app/models/integrations
      #{config.root}/app/models/sinks
    )

    config.api_only = true
    config.debug_exception_response_format = :api

    config.active_job.queue_adapter = :solid_queue
    config.active_storage.service = :local

    config.force_ssl = !Rails.env.development?

    # Add middleware to handle large file uploads
    require_relative '../app/middleware/large_upload_handler'
    config.middleware.insert_before Rack::Runtime, LargeUploadHandler

  end
end
