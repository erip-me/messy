# Server-side product analytics (PostHog).
#
# Emits high-signal lifecycle/business events (integration created, campaign
# sent, ...) keyed to the same distinct_id and account "group" the frontend
# uses, so browser and server events merge into one picture. Server-side
# capture is adblock-proof and also covers API-only traffic (e.g. Lalaaji
# creating campaigns with an environment key, where there is no browser and no
# signed-in user).
#
# Everything is a no-op unless POSTHOG_KEY is set (dev/test/OSS installs), and
# the actual HTTP call happens in AnalyticsEventJob, never on the request
# thread — safe to call inline from controllers.
module Analytics
  module_function

  def enabled?
    ENV["POSTHOG_KEY"].present?
  end

  # event    — String/Symbol event name, e.g. :integration_created
  # account  — the tenant the event belongs to (required; drives the group)
  # user     — the acting user, or nil for API/system events
  # properties — extra event props (keep values primitive/serializable)
  # timestamp  — ISO8601 string to backdate the event (used by rollups)
  def track(event, account:, user: nil, properties: {}, timestamp: nil)
    return unless enabled?
    return unless account

    AnalyticsEventJob.perform_later(
      event: event.to_s,
      distinct_id: user&.id ? user.id.to_s : "account_#{account.id}",
      account_id: account.id,
      account_name: account.name,
      account_plan: account.try(:plan),
      account_status: account.try(:status),
      user_email: user&.email,
      properties: properties.deep_stringify_keys,
      timestamp: timestamp
    )
  rescue StandardError => e
    # Telemetry must never break the request it is attached to.
    Rails.logger.warn("[Analytics] failed to enqueue #{event}: #{e.class}: #{e.message}")
  end
end
