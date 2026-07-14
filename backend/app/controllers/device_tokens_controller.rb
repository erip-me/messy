class DeviceTokensController < ApplicationController
  include ApiAuthentication

  # GET /device_tokens?email=x
  # List active device tokens for a customer.
  def index
    unless params[:email].present?
      return render json: { error: "email is required" }, status: :unprocessable_entity
    end

    customer = @account.customers.find_by(email: params[:email].downcase.strip)
    unless customer
      return render json: { device_tokens: [] }
    end

    tokens = customer.device_tokens.active
    tokens = tokens.for_platform(params[:platform]) if params[:platform].present?
    tokens = tokens.for_app(params[:app_id]) if params[:app_id].present?

    render json: {
      device_tokens: tokens.map { |dt| DeviceTokenResource.new(dt).to_h }
    }
  end

  # POST /device_tokens
  # Register a device token for push notifications.
  # Requires a customer to exist (find by email) or creates one.
  def create
    unless params[:token].present? && params[:email].present? && params[:platform].present?
      return render json: { error: "token, email, and platform are required" }, status: :unprocessable_entity
    end

    customer = @account.customers.find_or_create_by!(email: params[:email].downcase.strip) do |c|
      c.first_name = params[:first_name]
      c.last_name = params[:last_name]
    end
    customer.update!(last_seen_at: Time.current)

    # Remove same token if registered to a different customer within this account (device switched users)
    DeviceToken.where(account: @account, token: params[:token]).where.not(customer: customer).destroy_all

    device_token = customer.device_tokens.find_or_initialize_by(token: params[:token])
    device_token.assign_attributes(
      account: @account,
      platform: params[:platform],
      active: true,
      device_id: params[:device_id],
      app_id: params[:app_id],
      device_name: params[:device_name]
    )

    if device_token.save
      render json: { device_token: DeviceTokenResource.new(device_token).to_h }, status: :created
    else
      render json: { error: device_token.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # PATCH /device_tokens/:id
  # Update a device token (e.g. deactivate, change metadata).
  def update
    device_token = @account.device_tokens.find_by(id: params[:id])
    unless device_token
      return render json: { error: "Device token not found" }, status: :not_found
    end

    if device_token.update(params.permit(:active, :device_name, :app_id))
      render json: { device_token: DeviceTokenResource.new(device_token).to_h }
    else
      render json: { error: device_token.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # DELETE /device_tokens/:id
  def destroy
    device_token = @account.device_tokens.find_by(id: params[:id])

    if device_token
      device_token.deactivate!
      render json: { message: "Device token deactivated" }
    else
      render json: { error: "Device token not found" }, status: :not_found
    end
  end

  # POST /device_tokens/unregister
  # Deactivate a device token by its token value (for SDKs that don't know the record ID).
  def unregister
    unless params[:token].present?
      return render json: { error: "token is required" }, status: :unprocessable_entity
    end

    device_token = @account.device_tokens.find_by(token: params[:token])

    if device_token
      device_token.deactivate!
      render json: { message: "Device token deactivated" }
    else
      render json: { error: "Device token not found" }, status: :not_found
    end
  end

  private

end
