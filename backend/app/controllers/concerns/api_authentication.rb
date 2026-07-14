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
      @account = current_user.account_id ? Account.find_by(id: current_user.account_id) : nil
      if @account
        env_id = request.headers['X-Environment-Id']
        @environment = if env_id.present?
                         Environment.where(account_id: @account.id, id: env_id).first
                       end
        @environment ||= Environment.where(account_id: @account.id).first
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