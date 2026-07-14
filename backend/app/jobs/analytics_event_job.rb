require "net/http"
require "uri"
require "json"

# Delivers a single product event to PostHog's /batch/ endpoint. Kept off the
# request thread (enqueued by Analytics.track). Each call sends two events in
# one HTTP request: a $groupidentify to keep the account group's name/plan
# fresh, and the event itself associated with that group.
#
# Telemetry is best-effort: on any failure we log and discard rather than
# retrying, so a PostHog outage can never back up the job queue.
class AnalyticsEventJob < ApplicationJob
  queue_as :default

  discard_on StandardError

  def perform(event:, distinct_id:, account_id:, account_name: nil, account_plan: nil,
              account_status: nil, user_email: nil, properties: {}, timestamp: nil)
    api_key = ENV["POSTHOG_KEY"]
    return if api_key.blank?

    host = ENV.fetch("POSTHOG_HOST", "https://eu.i.posthog.com").chomp("/")
    group_key = account_id.to_s

    event_properties = (properties || {}).merge(
      "account_id" => account_id,
      "$groups" => { "account" => group_key }
    )
    event_properties["$set"] = { "email" => user_email } if user_email.present?

    capture = { event: event, distinct_id: distinct_id, properties: event_properties }
    capture[:timestamp] = timestamp if timestamp.present?

    batch = [
      {
        event: "$groupidentify",
        distinct_id: distinct_id,
        properties: {
          "$group_type" => "account",
          "$group_key" => group_key,
          "$group_set" => {
            "name" => account_name,
            "plan" => account_plan,
            "status" => account_status
          }.compact
        }
      },
      capture
    ]

    deliver(host, { api_key: api_key, batch: batch })
  end

  private

  def deliver(host, payload)
    uri = URI.parse("#{host}/batch/")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = (uri.scheme == "https")
    http.open_timeout = 3
    http.read_timeout = 5

    request = Net::HTTP::Post.new(uri.request_uri, "Content-Type" => "application/json")
    request.body = payload.to_json
    response = http.request(request)

    unless response.is_a?(Net::HTTPSuccess)
      Rails.logger.warn("[Analytics] PostHog responded #{response.code}: #{response.body.to_s[0, 200]}")
    end
  end
end
