module SuperAdmin
  # Account list view for the super-admin console.
  class AccountResource
    include Alba::Resource

    attributes :id, :name, :status, :plan, :payment_status, :trial_ends_at,
               :stripe_customer_id, :stripe_subscription_id,
               :subscription_cancel_at_period_end, :subscription_current_period_end,
               :onboarding_step, :onboarding_completed_at, :chat_enabled,
               :message_retention_days, :next_ticket_number, :tracking_domain,
               :created_at, :updated_at

    attribute :trial? do |account|
      account.trial?
    end

    attribute :trial_expired? do |account|
      account.trial_expired?
    end

    attribute :users do |account|
      account.users.map { |u| user_summary(u) }
    end

    def user_summary(user)
      { id: user.id, name: user.name, email: user.email,
        is_super_admin: user.is_super_admin, last_login_at: user.last_login_at }
    end
  end
end
