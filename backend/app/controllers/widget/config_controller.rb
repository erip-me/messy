module Widget
  class ConfigController < BaseController
    def show
      settings = @widget_settings || ChatWidgetSettings.new
      online_operators = OperatorProfile.where(account: @account).available
                                        .includes(:avatar_attachment, :avatar_blob).to_a

      render json: {
        settings: settings.as_widget_json,
        operators_online: online_operators.length,
        operators: settings&.show_operator_avatars ? online_operators.map(&:as_public_json) : [],
        tags: ConversationTag.where(account: @account).quick_replies.map { |t|
          { id: t.id, name: t.name }
        },
        is_within_business_hours: settings&.within_business_hours? != false
      }
    end
  end
end
