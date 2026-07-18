class DashboardController < ApplicationController
  include ApiAuthentication


  # GET /dashboard/stats
  def stats
    return render json: empty_stats if @environment.nil?

    # These aggregates scan the full messages table for the environment on every
    # request. Cache the raw query results for a short window keyed by the
    # environment (the only input the action reads) so repeated dashboard loads
    # don't re-run them. The cheap Ruby arithmetic below stays live.
    aggregates = Rails.cache.fetch(stats_cache_key, expires_in: 5.minutes) do
      {
        base_stats: @environment.messages.group(:type, :status).count,
        template_counts: @environment.messages
          .group("CASE WHEN template_id IS NULL THEN 'naked' ELSE 'templated' END")
          .count,
        scope_counts: @environment.messages.group(:scope).count,
        tag_stats: @environment.messages
          .group("CASE WHEN tags IS NULL OR tags = '[]' THEN 'untagged' ELSE 'tagged' END")
          .count,
        messages_per_day: calculate_messages_per_day,
        popular_tags: calculate_popular_tags
      }
    end

    base_stats      = aggregates[:base_stats]
    template_counts = aggregates[:template_counts]
    scope_counts    = aggregates[:scope_counts]
    tag_stats       = aggregates[:tag_stats]

    # Calculate all counts from the aggregated results
    total_messages = base_stats.values.sum
    email_processed = base_stats.select { |k, _| k[0] == 'EmailMessage' }.values.sum
    sms_processed = base_stats.select { |k, _| k[0] == 'SmsMessage' }.values.sum
    whatsapp_processed = base_stats.select { |k, _| k[0] == 'WhatsappMessage' }.values.sum
    mobile_push_processed = base_stats.select { |k, _| k[0] == 'MobilePushMessage' }.values.sum
    web_push_processed = base_stats.select { |k, _| k[0] == 'WebPushMessage' }.values.sum

    # 'delivered' is the post-webhook upgrade of 'sent' — both are successes.
    sent_messages = base_stats.select { |k, _| k[1].in?(%w[sent delivered]) }.values.sum
    email_sent = base_stats.select { |k, _| k[0] == 'EmailMessage' && k[1].in?(%w[sent delivered]) }.values.sum
    sms_sent = base_stats.select { |k, _| k[0] == 'SmsMessage' && k[1].in?(%w[sent delivered]) }.values.sum

    failed_messages = base_stats.select { |k, _| k[1] == 'failed' }.values.sum
    email_failed = base_stats[['EmailMessage', 'failed']] || 0

    stats = {
      messages: {
        total: total_messages,
        email_processed: email_processed,
        sms_processed: sms_processed,
        whatsapp_processed: whatsapp_processed,
        mobile_push_processed: mobile_push_processed,
        web_push_processed: web_push_processed
      },
      deliveries: {
        total: sent_messages,
        email_sent: email_sent,
        sms_sent: sms_sent
      },
      errors: {
        total: failed_messages,
        invalid_email: email_failed,
        bounced: 0 # Would need additional tracking
      },
      messages_per_day: aggregates[:messages_per_day],
      templates: {
        templated: template_counts['templated'] || 0,
        naked: template_counts['naked'] || 0
      },
      scope: {
        internal: scope_counts['internal'] || 0,
        external: (scope_counts['external'] || 0) + (scope_counts['any'] || 0)
      },
      tags: aggregates[:popular_tags],
      identification: {
        tagged: tag_stats['tagged'] || 0,
        untagged: tag_stats['untagged'] || 0
      }
    }

    render json: stats
  end

  private

  # Keyed by environment id (the only filter the action varies on). Bump the
  # version suffix if the shape of the cached aggregates changes.
  def stats_cache_key
    "dashboard_stats/v1/environment/#{@environment.id}"
  end

  def calculate_messages_per_day
    messages_by_day = @environment.messages
      .where('created_at >= ?', 7.days.ago)
      .group("DATE_TRUNC('day', created_at)")
      .count

    result = {}
    7.times do |i|
      date = Date.today - (6 - i).days
      label = date.strftime('%a').upcase
      count = messages_by_day.find { |k, _v| k.to_date == date }&.last || 0
      result[label] = count
    end

    result
  end

  def empty_stats
    days = 7.times.map { |i| (Date.today - (6 - i).days).strftime('%a').upcase }
    {
      messages:      { total: 0, email_processed: 0, sms_processed: 0, whatsapp_processed: 0, mobile_push_processed: 0, web_push_processed: 0 },
      deliveries:    { total: 0, email_sent: 0, sms_sent: 0 },
      errors:        { total: 0, invalid_email: 0, bounced: 0 },
      messages_per_day: days.each_with_object({}) { |day, h| h[day] = 0 },
      templates:     { templated: 0, naked: 0 },
      scope:         { internal: 0, external: 0 },
      tags:          {},
      identification: { tagged: 0, untagged: 0 }
    }
  end

  def calculate_popular_tags
    # Use PostgreSQL's jsonb_array_elements to unnest tags efficiently
    # This avoids loading all messages into memory
    sql = <<~SQL
      SELECT UPPER(jsonb_array_elements_text(tags::jsonb)) as tag, COUNT(*) as count
      FROM messages
      WHERE environment_id = $1
        AND tags IS NOT NULL
        AND tags != '[]'
      GROUP BY tag
      ORDER BY count DESC
      LIMIT 5
    SQL

    result = ActiveRecord::Base.connection.exec_query(sql, "popular_tags", [ActiveRecord::Relation::QueryAttribute.new("environment_id", @environment.id, ActiveRecord::Type::Integer.new)])
    result.to_a.each_with_object({}) { |row, hash| hash[row['tag']] = row['count'] }
  end
end