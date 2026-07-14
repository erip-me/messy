class IntegrationsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_account
  before_action :set_integration, only: %i[ show update destroy test ]

  # GET /integrations
  def index
    @integrations = @account.integrations.includes(:environment)

    render json: IntegrationResource.new(@integrations).serialize
  end

  # GET /integrations/1
  def show
    render json: IntegrationResource.new(@integration).serialize
  end

  # POST /integrations
  def create
    requested_type = integration_params[:type]
    if requested_type.present? && !Integration::PERMITTED_TYPES.include?(requested_type)
      return render json: { message: "Unsupported integration type" }, status: :unprocessable_entity
    end

    @integration = @account.integrations.new(integration_params)
    @integration.config = @integration.merge_filtered_config(@integration.config)

    if @integration.save
      Analytics.track("integration_created", account: @account, user: current_user,
                      properties: { kind: @integration.kind, vendor: @integration.vendor, type: @integration.type })
      render json: IntegrationResource.new(@integration).serialize, status: :created
    else
      render json: { message: @integration.errors.full_messages.join(', ') }, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /integrations/1
  def update
    attrs = integration_params
    attrs[:config] = @integration.merge_filtered_config(attrs[:config]) if attrs.key?(:config)

    if @integration.update(attrs)
      render json: IntegrationResource.new(@integration).serialize
    else
      render json: @integration.errors, status: :unprocessable_entity
    end
  end

  # POST /integrations/1/test
  def test
    unless params[:to].present?
      return render json: { error: "to is required" }, status: :unprocessable_entity
    end

    env = @integration.environment || @account.environments.first
    message_class = case @integration.kind
                    when "email" then EmailMessage
                    when "sms" then SmsMessage
                    when "whatsapp" then WhatsappMessage
                    when "mobile_push" then MobilePushMessage
                    when "web_push" then WebPushMessage
                    else Message
                    end

    message = message_class.new(
      account: @account,
      environment: env,
      to: params[:to],
      subject: params[:subject] || (@integration.kind == "email" ? "Messy Integration Test" : nil),
      body: params[:body] || "This is a test message from Messy.",
      status: :pending
    )
    message.save!

    begin
      @integration.deliver!(message, params[:to])
      message.update!(status: :sent, sent_at: Time.current)
      render json: { success: true, message_id: message.id, status: "sent" }
    rescue => e
      message.update!(status: :failed)
      render json: { success: false, error: e.message, message_id: message.id, status: "failed" }, status: :unprocessable_entity
    end
  end

  # DELETE /integrations/1
  def destroy
    @integration.destroy!
  end

  private

    def set_account
      @account = current_user.account
    end

    def set_integration
      @integration = @account.integrations.find(params[:id])
    end

    # Only allow a list of trusted parameters through.
    def integration_params
      params.require(:integration).permit(:environment_id, :type, :kind, :vendor, :active, config: {})
    end
end
