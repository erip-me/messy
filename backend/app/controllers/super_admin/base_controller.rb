class SuperAdmin::BaseController < ApplicationController
  before_action :require_super_admin!

  private

  def require_super_admin!
    unless current_user&.is_super_admin?
      render json: { error: 'Forbidden: Super admin access required' }, status: :forbidden
    end
  end
end