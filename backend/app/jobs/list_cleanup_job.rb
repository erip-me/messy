class ListCleanupJob < ApplicationJob
  queue_as :list_cleanup
  queue_with_priority 20

  retry_on StandardError, wait: 30.seconds, attempts: 3

  BATCH_SIZE = 100
  SLEEP_BETWEEN_VERIFICATIONS = 0.2

  def perform(segment_id, user_id)
    segment = Segment.find_by(id: segment_id)
    user = User.find_by(id: user_id)
    return unless segment && user

    all_eligible = segment.evaluate(segment.account)
      .where("unsubscribed_channels = '{}' OR NOT unsubscribed_channels ? 'email'")
    eligible_total = all_eligible.count
    already_checked = all_eligible.where("email_score_checked_at >= ?", 7.days.ago).count
    customers = all_eligible.where("email_score_checked_at IS NULL OR email_score_checked_at < ?", 7.days.ago)
    stats = { total: 0, skipped: already_checked, unsubscribed: 0, high: 0, medium: 0, low: 0, invalid: 0 }

    segment.update_columns(
      cleanup_status: "in_progress",
      cleanup_progress: already_checked,
      cleanup_total: eligible_total,
      cleanup_stats: nil,
      cleanup_started_at: Time.current,
      cleanup_completed_at: nil
    )

    customers.find_in_batches(batch_size: BATCH_SIZE) do |batch|
      batch.each do |customer|
        result = EmailVerifier.new(customer.email).verify

        customer.update_columns(
          email_score: result.score,
          email_score_checked_at: Time.current
        )

        if result.score == 0 && !customer.unsubscribed_from?('email')
          customer.unsubscribe_from!('email', reason: 'invalid_email')
          stats[:unsubscribed] += 1
        end

        case result.score
        when 70..100 then stats[:high] += 1
        when 40..69  then stats[:medium] += 1
        when 1..39   then stats[:low] += 1
        when 0       then stats[:invalid] += 1
        end

        stats[:total] += 1
        sleep SLEEP_BETWEEN_VERIFICATIONS
      end

      segment.update_columns(cleanup_progress: already_checked + stats[:total], updated_at: Time.current)
    end

    segment.update_columns(
      cleanup_status: "completed",
      cleanup_progress: eligible_total,
      cleanup_stats: stats,
      cleanup_completed_at: Time.current
    )

    UserMailer.with(
      user: user,
      segment: segment,
      stats: stats
    ).list_cleanup_complete.deliver_later
  rescue => e
    # Let retry_on handle retries — the skip filter ensures we resume where we left off.
    # Status stays "in_progress" so the retry picks it up cleanly.
    # Staleness detection in the controller handles the case where all retries are exhausted.
    raise
  end
end
