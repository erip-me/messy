module ApiAuthentication
  extend ActiveSupport::Concern

  included do
    before_action :authenticate_with_api_key
  end

  private

  def authenticate_with_api_key
    api_key = request.headers['Authorization']

    # Try API key first, then fall back to JWT
    if api_key.present? && valid_api_key?(api_key)
      return
    elsif current_user
      # Membership-checked; raises WorkspaceForbidden on a non-member X-Account-Id.
      @account = resolved_account
      if @account
        env_id = request.headers['X-Environment-Id']
        if env_id.present?
          # A named-but-unresolvable environment is an error, not a cue to pick
          # another one: silently falling through would show the caller a
          # different environment's data under the label they selected.
          @environment = Environment.where(account_id: @account.id, id: env_id).first
          raise ApplicationController::EnvironmentForbidden unless @environment
        else
          @environment = Environment.where(account_id: @account.id).first
        end
      end
      return
    end

    render json: { error: 'Unauthorized: API key is missing or invalid' }, status: :unauthorized
  end

  def valid_api_key?(api_key)
    @environment = Environment.active.find_by(api_key: api_key.split.last)
    @account = @environment.try(:account)

    @environment.present?
  end
end