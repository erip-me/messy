module Widget
  class BaseController < ApplicationController
    include ActionController::Cookies
    include WidgetAuthentication

    rescue_from ActiveRecord::RecordNotFound, with: :render_404
  end
end
