class EnvironmentsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_account
  before_action :require_account_admin!, only: %i[ create update destroy toggle_channel ]
  before_action :set_environment, only: %i[ show update destroy toggle_channel test ]

  # GET /environments
  def index
    @environments = @account.environments.all
    render json: EnvironmentResource.new(@environments).serialize
  end

  # GET /environments/1
  def show
    render json: EnvironmentResource.new(@environment).serialize
  end

  # POST /environments
  def create
    @environment = @account.environments.new(create_environment_params)

    if @environment.save
      render json: EnvironmentResource.new(@environment).serialize, status: :created, location: @environment
    else
      render json: @environment.errors, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /environments/1
  def update
    attrs = environment_params
    # Don't let the masked sentinel overwrite the stored token on a round-trip edit.
    attrs.delete(:whatsapp_token) if attrs[:whatsapp_token] == ConfigSecretFiltering::FILTERED

    if @environment.update(attrs)
      render json: EnvironmentResource.new(@environment).serialize
    else
      render json: @environment.errors, status: :unprocessable_entity
    end
  end

  # DELETE /environments/1
  def destroy
    @environment.destroy!
  end

  # POST /environments/1/toggle_channel
  def toggle_channel
    channel = params[:channel]

    unless %w[email sms whatsapp mobile_push web_push].include?(channel)
      render json: { error: 'Invalid channel' }, status: :bad_request
      return
    end

    field_name = "allow_#{channel}"
    current_value = @environment.send(field_name)
    @environment.update!(field_name => !current_value)

    render json: EnvironmentResource.new(@environment).serialize
  end

  # POST /environments/1/test
  def test
    channel  = params[:channel].to_s
    to       = params[:to].to_s.strip
    subject  = params[:subject].to_s.strip
    body     = params[:body].to_s.strip

    unless %w[email sms whatsapp push].include?(channel)
      render json: { error: 'Invalid channel. Must be one of: email, sms, whatsapp, push' }, status: :bad_request
      return
    end

    if to.blank? || body.blank?
      render json: { error: '`to` and `body` are required' }, status: :bad_request
      return
    end

    # Map frontend channel name to allow field
    allow_field = case channel
                  when 'email'    then :allow_email
                  when 'sms'      then :allow_sms
                  when 'whatsapp' then :allow_whatsapp
                  when 'push'     then :allow_mobile_push
                  end

    unless @environment.send(allow_field)
      render json: { error: "#{channel.capitalize} is not enabled for this environment" }, status: :unprocessable_entity
      return
    end

    # Build the appropriate message type
    message_class = case channel
                    when 'email'    then 'EmailMessage'
                    when 'sms'      then 'SmsMessage'
                    when 'whatsapp' then 'WhatsappMessage'
                    when 'push'     then 'MobilePushMessage'
                    end

    attrs = {
      account_id:     @environment.account_id,
      environment_id: @environment.id,
      to:             to,
      body:           body,
      status:         :pending
    }
    attrs[:subject] = subject.presence || "[Test] Message from #{@environment.name}" if channel == 'email'

    message = message_class.constantize.new(attrs)

    if message.save
      # Attempt delivery (fire-and-forget — if no integration, it will fail gracefully)
      begin
        DeliverMessageJob.perform_later(message)
      rescue => e
        Rails.logger.warn "Test message queued but delivery job failed: #{e.message}"
      end
      render json: { success: true, message_id: message.id, status: 'queued' }
    else
      render json: { error: message.errors.full_messages.join(', ') }, status: :unprocessable_entity
    end
  end

  private

    def set_account
      @account = current_user.account
    end

    # Use callbacks to share common setup or constraints between actions.
    def set_environment
      @environment = @account.environments.find(params[:id])
    end

    # Columns a client is allowed to set. Notably excludes api_key and account_id,
    # which are tenant secrets / ownership and must never be client-assignable.
    PERMITTED_ENVIRONMENT_KEYS = %i[
      name tag
      allow_email allow_sms allow_whatsapp allow_mobile_push allow_web_push
      whatsapp_phone_id whatsapp_token
      notification_email_integration_id campaign_email_integration_id
    ].freeze

    # Only allow a list of trusted parameters through.
    def environment_params
      params.require(:environment).permit(*PERMITTED_ENVIRONMENT_KEYS)
    end

    # `create` accepts a raw (unwrapped) JSON body, so build params from it and
    # apply the same allowlist used by `update`.
    def create_environment_params
      ActionController::Parameters.new(JSON.parse(request.body.read))
                                  .permit(*PERMITTED_ENVIRONMENT_KEYS)
    end
end
