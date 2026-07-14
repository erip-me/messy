class ApplicationController < ActionController::API
  include ApplicationHelper

  # rescue_from handlers are matched most-recently-defined first, so the catch-all
  # StandardError must be declared FIRST and the specific handlers after it —
  # otherwise StandardError shadows them and e.g. validation errors leak as 500s.
  rescue_from StandardError, with: :render_internal_server_error
  rescue_from ActionController::RoutingError, with: :render_404
  rescue_from ActiveRecord::RecordNotFound, with: :render_404
  rescue_from ActiveRecord::RecordInvalid, with: :render_unprocessable_entity

  def render_404
    render json: { error: "Not found" }, status: :not_found
  end

  def render_unprocessable_entity(exception)
    render json: { error: exception.record.errors.full_messages }, status: :unprocessable_entity
  end

  def render_internal_server_error(exception)
    # Log full details server-side; never leak exception internals (SQL, paths) to clients.
    Rails.logger.error("#{exception.class}: #{exception.message}\n#{exception.backtrace&.first(20)&.join("\n")}")
    render json: { error: "Something went wrong" }, status: :internal_server_error
  end

  def current_user
    @current_user ||= user_from_jwt || User.find_by(id: session[:user_id])
  end

  def authenticate_user!
    render json: { error: 'Not authorized' }, status: :unauthorized unless current_user
  end

  # Gate account-management actions (users, environments, account settings) to
  # account admins. Members get a 403 rather than silently being allowed.
  def require_account_admin!
    return if current_user&.account_admin?
    render json: { error: 'Admin privileges required' }, status: :forbidden
  end

  # Cloud-only billing gate for send endpoints. Self-hosted installs (no Stripe
  # key) are never blocked, and `free` stays open for self-host and comped
  # accounts — only an expired trial blocks sending.
  def require_active_billing!
    return unless Stripe.api_key.present?
    return unless @account&.trial_expired?
    render json: { error: 'Your trial has ended. Pick a plan under Settings → Billing to keep sending.' },
           status: :payment_required
  end

  private

  def user_from_jwt
    header = request.headers['Authorization']
    return nil unless header&.start_with?('Bearer ')

    token = header.split(' ').last
    decoded = JWT.decode(token, Rails.application.secret_key_base, true, algorithm: 'HS256')
    User.find_by(id: decoded.first['id'])
  rescue JWT::DecodeError, JWT::ExpiredSignature
    nil
  end
end
