module WidgetAuthentication
  extend ActiveSupport::Concern

  included do
    before_action :authenticate_visitor
    skip_before_action :authenticate_with_api_key, raise: false
  end

  private

  def authenticate_visitor
    widget_key = request.headers["X-Widget-Key"] || params[:widget_key]

    unless widget_key.present?
      return render json: { error: "Widget key is required" }, status: :unauthorized
    end

    @widget_settings = ChatWidgetSettings.find_by(widget_key: widget_key)
    @account = @widget_settings&.account

    unless @account&.chat_enabled? && @widget_settings&.enabled?
      return render json: { error: "Chat not available" }, status: :not_found
    end

    unless valid_origin?
      return render json: { error: "Origin not allowed" }, status: :forbidden
    end

    @visitor_token = cookies.signed[:messy_visitor_token] || request.headers["X-Visitor-Token"]
    unless @visitor_token
      @visitor_token = SecureRandom.uuid
      cookies.signed[:messy_visitor_token] = {
        value: @visitor_token,
        httponly: true,
        secure: Rails.env.production?,
        same_site: :None,
        expires: 1.year.from_now
      }
    end

  end

  def valid_origin?
    return true unless Rails.env.production?
    return true unless @widget_settings

    allowed = @widget_settings.allowed_domains
    return true if allowed.blank? || allowed.include?("*")

    origin = request.headers["Origin"]
    return false if origin.blank?

    host = URI.parse(origin).host rescue nil
    return false if host.blank?

    allowed.any? { |domain| host == domain || host.end_with?(".#{domain}") }
  end

  def find_or_create_customer
    @customer = Customer.find_by(account: @account, anonymous_token: @visitor_token)
    unless @customer
      @customer = Customer.create!(
        account: @account,
        anonymous_token: @visitor_token,
        first_name: generate_visitor_name,
        last_seen_at: Time.current
      )
    end
    @customer.touch_last_seen
    @customer
  end

  def generate_visitor_name
    adjectives = %w[Friendly Curious Bold Gentle Swift Bright Calm Clever Brave Merry Jolly Kind Warm Happy Lucky Noble Wise Quick Sharp Keen]
    animals = %w[Fox Penguin Eagle Panda Dolphin Owl Bear Wolf Tiger Lion Hawk Falcon Rabbit Deer Otter Koala Raven Swan Crane Sparrow]
    "#{adjectives.sample} #{animals.sample}"
  end
end
