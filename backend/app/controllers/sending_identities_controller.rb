class SendingIdentitiesController < ApplicationController
  # Listing is also open to an environment API key (read-only), scoped to the
  # key's account; everything else needs a signed-in user.
  before_action :authenticate_user!, except: :index
  before_action :set_identity, only: [:update, :destroy]

  def index
    account = current_user ? resolved_account : api_key_account
    return render json: { error: "Not authorized" }, status: :unauthorized unless account

    identities = account.sending_identities.order(is_default: :desc, from_email: :asc)
    identities = identities.where(personal: ActiveModel::Type::Boolean.new.cast(params[:personal])) if params[:personal].present?
    render json: SendingIdentityResource.new(identities).serialize
  end

  def create
    identity = resolved_account.sending_identities.new(identity_params)
    persist(identity, status: :created)
  end

  def update
    @identity.assign_attributes(identity_params)
    persist(@identity)
  end

  def destroy
    @identity.destroy
    render json: { message: "Sending identity deleted" }
  end

  private

  def set_identity
    @identity = resolved_account.sending_identities.find_by(id: params[:id])
    render json: { error: "Not found" }, status: :not_found unless @identity
  end

  def identity_params
    params.permit(:from_name, :from_email, :is_default, :personal)
  end

  def api_key_account
    key = request.headers["Authorization"].to_s.split.last
    key.present? ? Environment.active.find_by(api_key: key)&.account : nil
  end

  # Save, demoting any other default first so there's at most one default.
  def persist(identity, status: :ok)
    ActiveRecord::Base.transaction do
      if identity.is_default
        resolved_account.sending_identities.where.not(id: identity.id).update_all(is_default: false)
      end
      identity.save!
    end
    render json: SendingIdentityResource.new(identity).serialize, status: status
  rescue ActiveRecord::RecordInvalid => e
    render json: { errors: e.record.errors.full_messages }, status: :unprocessable_entity
  end
end
