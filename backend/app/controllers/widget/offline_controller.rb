module Widget
  class OfflineController < BaseController
    def create
      unless params[:name].present? && params[:email].present? && params[:message].present?
        return render json: { error: "Name, email, and message are required" }, status: :unprocessable_entity
      end

      OfflineMessageJob.perform_later(
        @account.id,
        params[:name],
        params[:email],
        params[:message],
        { visitor_token: @visitor_token, ip: request.remote_ip, user_agent: request.user_agent }
      )

      render json: { success: true, message: "Your message has been sent. We'll get back to you soon." }
    end
  end
end
