class HelpdeskController < ApplicationController
  include ApiAuthentication

  rescue_from ActiveRecord::RecordNotFound, with: :render_404

  def stats
    tickets = @account.conversations.email_tickets

    today = Time.current.beginning_of_day
    week_start = Time.current.beginning_of_week

    # Per-operator breakdown — single grouped query for all statuses
    operator_stats = tickets
      .where(status: [:open, :pending, :resolved])
      .where.not(assigned_user_id: nil)
      .group(:assigned_user_id, :status)
      .count

    # Resolved today per operator — single grouped query instead of N+1
    resolved_today_counts = tickets
      .where(status: :resolved, assigned_user_id: operator_stats.keys.map(&:first).uniq)
      .where("resolved_at >= ?", today)
      .group(:assigned_user_id)
      .count

    operator_ids = operator_stats.keys.map(&:first).uniq
    operators = User.where(id: operator_ids).includes(:operator_profile).index_by(&:id)

    per_operator = operator_ids.map do |uid|
      user = operators[uid]
      profile = user&.operator_profile
      {
        user_id: uid,
        name: profile&.display_name || user&.name,
        avatar_url: profile&.avatar_url,
        open_count: operator_stats[[uid, "open"]] || 0,
        pending_count: operator_stats[[uid, "pending"]] || 0,
        resolved_today: resolved_today_counts[uid] || 0
      }
    end

    # Status counts — single query with conditional aggregation
    status_counts = tickets.group(:status).count

    render json: {
      open_count: status_counts["open"] || 0,
      pending_count: status_counts["pending"] || 0,
      resolved_count: status_counts["resolved"] || 0,
      closed_count: status_counts["closed"] || 0,
      unassigned_count: tickets.where(status: [:open, :pending]).unassigned.count,
      tickets_today: tickets.where("conversations.created_at >= ?", today).count,
      tickets_this_week: tickets.where("conversations.created_at >= ?", week_start).count,
      avg_first_response_seconds: tickets.where.not(first_response_at: nil).average("EXTRACT(EPOCH FROM first_response_at - created_at)")&.round,
      avg_resolution_seconds: tickets.where.not(resolved_at: nil).average("EXTRACT(EPOCH FROM resolved_at - created_at)")&.round,
      per_operator: per_operator
    }
  end
end
