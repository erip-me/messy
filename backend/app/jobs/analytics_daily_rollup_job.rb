# Rolls the previous day's message volume up into ONE PostHog event per active
# account. This is deliberately O(accounts-per-day), not per-message: message
# sends can be very high volume, so we never capture an event on the send hot
# path (that would add load to the send pipeline and the shared DB, and swamp
# PostHog). Runs on the dedicated recurring worker (see config/recurring.yml).
class AnalyticsDailyRollupJob < ApplicationJob
  queue_as :default

  discard_on StandardError

  # date_str — optional ISO date to (re)compute a specific day; defaults to
  #            yesterday, which is the only fully-complete day at run time.
  def perform(date_str = nil)
    return unless Analytics.enabled?

    day = date_str ? Date.parse(date_str) : Date.current - 1
    range = day.beginning_of_day..day.end_of_day
    status_labels = Message.statuses.invert # { 10 => "sent", 15 => "delivered", ... }

    raw = Message.where(created_at: range).group(:account_id, :status).count
    per_account = Hash.new { |h, k| h[k] = Hash.new(0) }
    raw.each do |(account_id, status), count|
      label = status.is_a?(Integer) ? status_labels[status] : status.to_s
      per_account[account_id][label] += count
    end

    return if per_account.empty?

    Account.where(id: per_account.keys).find_each do |account|
      counts = per_account[account.id]
      Analytics.track(
        "messages_daily",
        account: account,
        properties: {
          date: day.iso8601,
          total: counts.values.sum,
          sent: counts["sent"].to_i + counts["delivered"].to_i,
          delivered: counts["delivered"].to_i,
          failed: counts["failed"].to_i,
          rejected: counts["rejected"].to_i
        },
        timestamp: day.end_of_day.iso8601
      )
    end
  end
end
