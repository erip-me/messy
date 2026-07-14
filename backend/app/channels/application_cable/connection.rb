module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_user, :visitor_token, :account_id

    def connect
      self.current_user = find_verified_user
      self.visitor_token = find_visitor_token
      self.account_id = find_account_id

      # Require either an authenticated user or a widget_key-derived account_id.
      # Never accept a bare account_id from params — that's not authentication.
      reject_unauthorized_connection unless current_user || (visitor_token && account_id)

      # For widget connections, validate origin against allowed_domains
      verify_widget_origin! if @widget_settings && !current_user
    end

    private

    def find_verified_user
      token = cookies[:ws_token].presence || request.params[:token]
      return nil unless token

      decoded = JWT.decode(token, Rails.application.secret_key_base, true, algorithm: "HS256")
      User.find_by(id: decoded.first["id"])
    rescue JWT::DecodeError, JWT::ExpiredSignature
      nil
    end

    def find_visitor_token
      request.params[:visitor_token].presence
    end

    def find_account_id
      if current_user
        current_user.account_id
      elsif request.params[:widget_key].present?
        @widget_settings = ChatWidgetSettings.find_by(widget_key: request.params[:widget_key])
        @widget_settings&.account_id
      end
      # No fallback to bare account_id from params — that would let anyone claim any account
    end

    def verify_widget_origin!
      settings = @widget_settings
      return reject_unauthorized_connection unless settings

      allowed = settings.allowed_domains || ["*"]
      return if allowed.include?("*")

      origin = request.origin || request.headers["Origin"]
      return reject_unauthorized_connection unless origin

      origin_host = URI.parse(origin).host rescue nil
      return reject_unauthorized_connection unless origin_host

      reject_unauthorized_connection unless allowed.any? { |domain|
        domain == origin_host || origin_host.end_with?(".#{domain}")
      }
    end
  end
end
