require "test_helper"

class RateLimitingTest < ActionDispatch::IntegrationTest
  setup do
    @throttling_was_enabled = Rack::Attack.enabled
    Rack::Attack.enabled = true
    Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new
  end

  teardown do
    Rack::Attack.enabled = @throttling_was_enabled
  end

  test "widget identify endpoint is throttled per IP" do
    headers = { "CONTENT_TYPE" => "application/json", "X-Forwarded-For" => "203.0.113.7" }

    statuses = Array.new(62) do
      post "/widget/v1/identify", params: { email: "x@example.com" }.to_json, headers: headers
      response.status
    end

    assert_includes statuses, 429, "expected the widget identify endpoint to start returning 429 under a burst"
  end

  test "customers identify endpoint is throttled per IP" do
    headers = { "CONTENT_TYPE" => "application/json", "X-Forwarded-For" => "203.0.113.8" }

    statuses = Array.new(62) do
      post "/customers/identify", params: { email: "x@example.com" }.to_json, headers: headers
      response.status
    end

    assert_includes statuses, 429
  end
end
