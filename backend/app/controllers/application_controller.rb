class ApplicationController < ActionController::API
  include ApplicationHelper

  # rescue_from handlers are matched most-recently-defined first, so the catch-all
  # StandardError must be declared FIRST and the specific handlers after it —
  # otherwise StandardError shadows them and e.g. validation errors leak as 500s.
  # Raised when the caller names a workspace (X-Account-Id) they are not a member
  # of. Deliberately NOT a 404 — the id is well-formed, the access isn't granted.
  class WorkspaceForbidden < StandardError; end

  # Raised when X-Environment-Id names an environment that doesn't belong to the
  # resolved workspace — most often a stale id left over from a workspace switch.
  # Carries a machine-readable code so the client can clear its selection and
  # retry instead of wedging.
  class EnvironmentForbidden < StandardError; end

  rescue_from StandardError, with: :render_internal_server_error
  rescue_from ActionController::RoutingError, with: :render_404
  rescue_from ActiveRecord::RecordNotFound, with: :render_404
  rescue_from ActiveRecord::RecordInvalid, with: :render_unprocessable_entity
  # Every controller reaches for params.require, and the StandardError catch-all
  # above would otherwise turn a missing param into a 500. It's a bad request.
  rescue_from ActionController::ParameterMissing, with: :render_parameter_missing
  rescue_from WorkspaceForbidden, with: :render_workspace_forbidden
  rescue_from EnvironmentForbidden, with: :render_environment_forbidden

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

  def render_parameter_missing(exception)
    render json: { error: "Missing required parameter: #{exception.param}" }, status: :bad_request
  end

  def render_workspace_forbidden
    render json: { error: 'You do not have access to that workspace', code: 'unknown_workspace' },
           status: :forbidden
  end

  def render_environment_forbidden
    render json: { error: 'That environment does not belong to this workspace', code: 'unknown_environment' },
           status: :forbidden
  end

  def current_user
    @current_user ||= user_from_jwt || User.find_by(id: session[:user_id])
  end

  # The workspace (Account) this request acts in.
  #
  # The client picks it with X-Account-Id, but the header is only ever a request:
  # it is re-checked against the caller's memberships, exactly as X-Environment-Id
  # is re-checked against the resolved account. A non-member id raises rather than
  # falling back, so "wrong workspace selected" can never silently become
  # "you're now looking at someone else's data".
  #
  # With no header we fall back to the user's default workspace (users.account_id),
  # which keeps every single-workspace caller working unchanged.
  def resolved_account
    return @resolved_account if defined?(@resolved_account)

    @resolved_account = begin
      user = current_user
      if user.nil?
        nil
      elsif (requested = request.headers['X-Account-Id']).present?
        account = Account.find_by(id: requested)
        raise WorkspaceForbidden unless account && user.member_of?(account)
        account
      else
        # users.account_id is only a pointer and can go stale — removed from that
        # workspace, or an invitation that was never accepted. Check it like any
        # other candidate rather than trusting the column, and fall back to a
        # workspace they do belong to.
        default = user.account
        user.member_of?(default) ? default : user.accounts.first
      end
    end
  end

  def authenticate_user!
    render json: { error: 'Not authorized' }, status: :unauthorized unless current_user
  end

  # Gate workspace-management actions (users, environments, workspace settings) to
  # admins *of the workspace being acted on*. Members get a 403 rather than
  # silently being allowed.
  def require_account_admin!
    return if current_user&.account_admin?(resolved_account)
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
