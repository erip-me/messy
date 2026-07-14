# Set Rack query limit environment variable BEFORE any gems are loaded
# This must be the FIRST thing in boot.rb
ENV['RACK_QUERY_PARSER_BYTESIZE_LIMIT'] = (35 * 1024 * 1024).to_s # 35MB for 25MB files with base64 overhead

ENV["PORT"] ||= "3300"

ENV["BUNDLE_GEMFILE"] ||= File.expand_path("../Gemfile", __dir__)

require "bundler/setup" # Set up gems listed in the Gemfile.
require "bootsnap/setup" # Speed up boot time by caching expensive operations.
