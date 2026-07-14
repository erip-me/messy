class BillingController < ApplicationController
  include ApiAuthentication

  # Stripe -> server callback; authenticated by signature, not by API key/JWT.
  skip_before_action :authenticate_with_api_key, only: :webhook
  before_action :require_account_admin!, only: %i[checkout portal]
  before_action :require_stripe!, only: %i[checkout portal invoices]

  # GET /billing — current plan + subscription state for the account.
  def show
    render json: {
      configured: stripe_configured?,
      plan: @account.plan,
      plan_name: @account.plan_display_name,
      payment_status: @account.payment_status,
      current_period_end: @account.subscription_current_period_end,
      cancel_at_period_end: @account.subscription_cancel_at_period_end,
      has_subscription: @account.stripe_subscription_id.present?,
      plans: Account::PLANS.map do |key, v|
        { key: key, name: v[:name], amount: v[:amount], coming_soon: v[:coming_soon],
          purchasable: key != "free" && !v[:coming_soon] && Account.price_id_for(key).present? }
      end
    }
  end

  # POST /billing/checkout { plan } — start a Stripe Checkout session for a paid plan.
  def checkout
    plan = params[:plan].to_s
    return render json: { error: "Unknown plan" }, status: :unprocessable_entity unless Account::PAID_PLANS.include?(plan)
    return render json: { error: "This plan isn't available yet" }, status: :unprocessable_entity if Account::PLANS.dig(plan, :coming_soon)
    # An existing subscription must be changed via the portal — a second Checkout
    # would create a second subscription and double-bill the account.
    return render json: { error: "You already have a subscription. Use the billing portal to switch plans." }, status: :unprocessable_entity if @account.stripe_subscription_id.present?

    price = Account.price_id_for(plan)
    return render json: { error: "Plan not configured" }, status: :unprocessable_entity if price.blank?

    session = Stripe::Checkout::Session.create(
      mode: "subscription",
      customer: ensure_stripe_customer,
      line_items: [{ price: price, quantity: 1 }],
      client_reference_id: @account.id.to_s,
      subscription_data: { metadata: { account_id: @account.id, plan: plan } },
      billing_address_collection: "required",
      tax_id_collection: { enabled: true },
      automatic_tax: { enabled: ENV["STRIPE_AUTOMATIC_TAX"] != "false" },
      customer_update: { address: "auto", name: "auto" },
      allow_promotion_codes: true,
      success_url: "#{frontend_url}/settings/billing?status=success",
      cancel_url: "#{frontend_url}/settings/billing?status=cancelled"
    )
    render json: { url: session.url }
  end

  # POST /billing/portal — Stripe-hosted portal: upgrade/downgrade, cancel, invoices, payment method.
  def portal
    return render json: { error: "No billing account yet" }, status: :unprocessable_entity if @account.stripe_customer_id.blank?
    session = Stripe::BillingPortal::Session.create(
      customer: @account.stripe_customer_id,
      return_url: "#{frontend_url}/settings/billing"
    )
    render json: { url: session.url }
  end

  # GET /billing/invoices — tax invoices for the account (downloadable PDFs).
  def invoices
    return render json: { invoices: [] } if @account.stripe_customer_id.blank?
    list = Stripe::Invoice.list(customer: @account.stripe_customer_id, limit: 24)
    render json: {
      invoices: list.data.map do |i|
        { number: i.number, status: i.status, amount_paid: i.amount_paid, amount_due: i.amount_due,
          currency: i.currency, created: Time.at(i.created), pdf: i.invoice_pdf, hosted_url: i.hosted_invoice_url }
      end
    }
  end

  # POST /billing/webhook — Stripe event sink that keeps the account's plan in sync.
  def webhook
    payload = request.body.read
    secret = ENV["STRIPE_WEBHOOK_SECRET"]
    if secret.blank?
      Rails.logger.error("Stripe webhook rejected: STRIPE_WEBHOOK_SECRET is not set")
      return head :bad_request
    end

    event =
      begin
        Stripe::Webhook.construct_event(payload, request.env["HTTP_STRIPE_SIGNATURE"], secret)
      rescue Stripe::SignatureVerificationError, JSON::ParserError
        return head :bad_request
      end
    return head :bad_request if event.nil?

    handle_event(event)
    head :ok
  end

  private

  def frontend_url
    ENV.fetch("FRONTEND_URL", "https://app.messy.sh")
  end

  def stripe_configured?
    Stripe.api_key.present?
  end

  def require_stripe!
    render json: { error: "Billing is not configured" }, status: :service_unavailable unless stripe_configured?
  end

  def ensure_stripe_customer
    return @account.stripe_customer_id if @account.stripe_customer_id.present?
    customer = Stripe::Customer.create(
      name: @account.name,
      email: current_user&.email,
      metadata: { account_id: @account.id }
    )
    @account.update!(stripe_customer_id: customer.id)
    customer.id
  end

  def account_from_customer(customer_id)
    customer_id.present? && Account.find_by(stripe_customer_id: customer_id)
  end

  def handle_event(event)
    obj = event.data.object
    case event.type
    when "checkout.session.completed"
      account = Account.find_by(id: obj.client_reference_id) || account_from_customer(obj.customer)
      account&.update(stripe_customer_id: obj.customer) if account && obj.customer
      apply_subscription(account, Stripe::Subscription.retrieve(obj.subscription)) if account && obj.subscription
    when "customer.subscription.created", "customer.subscription.updated"
      apply_subscription(account_from_customer(obj.customer), obj)
    when "customer.subscription.deleted"
      # Land in an already-expired trial: sending stays blocked until they pick a
      # plan again. (`free` is reserved for self-host and comped accounts.)
      account_from_customer(obj.customer)&.update(
        plan: "trial", trial_ends_at: Time.current, payment_status: "canceled",
        stripe_subscription_id: nil, subscription_cancel_at_period_end: false
      )
    when "invoice.payment_failed"
      account_from_customer(obj.customer)&.update(payment_status: "past_due")
    when "invoice.paid"
      account_from_customer(obj.customer)&.update(payment_status: "active")
    end
  rescue Stripe::StripeError => e
    Rails.logger.error("Stripe webhook handling failed: #{e.message}")
  end

  def apply_subscription(account, sub)
    return unless account && sub
    plan = sub.metadata&.[]("plan").presence || Account.plan_for_price(sub.items&.data&.first&.price&.id)
    period_end = sub.respond_to?(:current_period_end) && sub.current_period_end ? Time.at(sub.current_period_end) : nil
    account.update(
      plan: plan.presence || account.plan,
      stripe_subscription_id: sub.id,
      payment_status: %w[active trialing].include?(sub.status) ? "active" : sub.status,
      subscription_current_period_end: period_end,
      subscription_cancel_at_period_end: sub.cancel_at_period_end || false
    )
  end
end
