class SendingIdentitiesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_identity, only: [:update, :destroy]

  def index
    render json: SendingIdentityResource.new(current_user.account.sending_identities.order(is_default: :desc, from_email: :asc)).serialize
  end

  def create
    identity = current_user.account.sending_identities.new(identity_params)
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
    @identity = current_user.account.sending_identities.find_by(id: params[:id])
    render json: { error: "Not found" }, status: :not_found unless @identity
  end

  def identity_params
    params.permit(:from_name, :from_email, :is_default)
  end

  # Save, demoting any other default first so there's at most one default.
  def persist(identity, status: :ok)
    ActiveRecord::Base.transaction do
      if identity.is_default
        current_user.account.sending_identities.where.not(id: identity.id).update_all(is_default: false)
      end
      identity.save!
    end
    render json: SendingIdentityResource.new(identity).serialize, status: status
  rescue ActiveRecord::RecordInvalid => e
    render json: { errors: e.record.errors.full_messages }, status: :unprocessable_entity
  end
end
