class OperatorProfilesController < ApplicationController
  include ApiAuthentication

  def index
    profiles = OperatorProfile.where(account_id: @account.id)
                              .includes(:user, avatar_attachment: :blob)
                              .order(:sort_order, :id)

    render json: {
      operator_profiles: profiles.map { |p| OperatorProfileListResource.new(p).to_h }
    }
  end

  def show
    profile = current_user.operator_profile
    if profile
      render json: { operator_profile: OperatorProfileResource.new(profile).to_h }
    else
      render json: { operator_profile: nil }
    end
  end

  def heartbeat
    profile = current_user.operator_profile
    if profile&.online?
      profile.heartbeat!
      head :ok
    else
      head :no_content
    end
  end

  def update
    profile = current_user.operator_profile || current_user.build_operator_profile(account: @account)
    profile.update!(profile_params)
    profile.heartbeat! if profile.online?

    if params[:avatar].present?
      profile.avatar.attach(params[:avatar])
    end

    # Broadcast presence update so widgets see the change immediately
    OperatorPresenceChannel.broadcast_presence_for(current_user.account_id)

    render json: { operator_profile: OperatorProfileResource.new(profile).to_h }
  end

  def reorder
    order = params.require(:order) # array of { id:, sort_order: }
    OperatorProfile.transaction do
      order.each do |entry|
        OperatorProfile.where(id: entry[:id], account_id: @account.id)
                       .update_all(sort_order: entry[:sort_order])
      end
    end
    head :ok
  end

  private

  def profile_params
    params.permit(:public_name, :bio, :availability, :auto_assign, :max_concurrent_chats)
  end


end
