class ChatSettingsController < ApplicationController
  include ApiAuthentication

  def show
    settings = @account.chat_widget_settings || @account.create_chat_widget_settings!
    tags = @account.conversation_tags.ordered
    api_url = ENV.fetch("API_URL", request.base_url)

    operators = @account.users.joins(:operator_profile).map do |u|
      profile = u.operator_profile
      {
        id: u.id,
        name: profile.public_name.presence || u.name,
        avatar_url: profile.avatar.attached? ? Rails.application.routes.url_helpers.rails_blob_url(profile.avatar) : nil
      }
    end

    render json: {
      chat_enabled: @account.chat_enabled?,
      widget_settings: settings.as_widget_json.merge(
        auto_close_hours: settings.auto_close_hours,
        welcome_triggers: settings.welcome_triggers,
        allowed_domains: settings.allowed_domains,
        widget_key: settings.widget_key,
        embed_snippet: settings.embed_snippet(api_url)
      ),
      tags: tags.map { |t| { id: t.id, name: t.name, is_quick_reply: t.is_quick_reply, sort_order: t.sort_order } },
      operators: operators
    }
  end

  def update
    if params.key?(:chat_enabled)
      @account.update!(chat_enabled: params[:chat_enabled])
    end

    settings = @account.chat_widget_settings || @account.build_chat_widget_settings
    settings.update!(settings_params) if params[:widget_settings].present?

    settings.logo.attach(params[:logo]) if params[:logo].present?
    settings.header_background_image.attach(params[:header_background_image]) if params[:header_background_image].present?
    settings.chat_background_image.attach(params[:chat_background_image]) if params[:chat_background_image].present?

    settings.logo.purge if params[:remove_logo] == "true"
    settings.header_background_image.purge if params[:remove_header_background_image] == "true"
    settings.chat_background_image.purge if params[:remove_chat_background_image] == "true"

    render json: { chat_enabled: @account.chat_enabled?, widget_settings: settings.as_widget_json }
  end

  private

  def settings_params
    params.require(:widget_settings).except(
      :widget_key, :embed_snippet, :logo_url,
      :header_background_image_url, :chat_background_image_url
    ).permit(
      :enabled, :title, :primary_color, :secondary_color, :text_color,
      :button_color, :button_text_color, :header_color, :header_text_color, :send_button_color, :send_button_text_color,
      :position, :greeting_message, :offline_message, :require_email_before_chat,
      :show_operator_avatars, :show_operator_count, :business_hours_enabled,
      :timezone, :auto_close_hours,
      business_hours: {},
      welcome_triggers: [],
      allowed_domains: []
    )
  end
end
