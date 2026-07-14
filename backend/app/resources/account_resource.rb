# The account as the dashboard sees it (settings, billing state, onboarding).
class AccountResource
  include Alba::Resource

  attributes :id, :name, :status, :plan, :payment_status, :trial_ends_at,
             :stripe_customer_id, :stripe_subscription_id,
             :subscription_cancel_at_period_end, :subscription_current_period_end,
             :onboarding_step, :onboarding_completed_at, :chat_enabled,
             :message_retention_days, :next_ticket_number, :tracking_domain,
             :created_at, :updated_at
end
