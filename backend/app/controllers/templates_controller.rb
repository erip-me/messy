class TemplatesController < ApplicationController
  include ApiAuthentication

  before_action :load_template, only: %i[ show update destroy render_preview send_test add_attachment remove_attachment ]

  # GET /templates
  def index
    @templates = if params[:scope] == 'account' && @account
      Template.where(
        environment_id: @account.environments.select(:id),
        is_deleted: false
      )
    else
      @environment.templates.all
    end

    @templates = @templates.where(channel: params[:channel]) if params[:channel].present?
    @templates = @templates.where(sending_identity_id: params[:sending_identity_id]) if params[:sending_identity_id].present?
    # Neither branch was ordered, so the list came back in whatever order Postgres
    # chose and could reshuffle between identical requests.
    @templates = @templates.with_attached_attachments.order(:id)

    render json: TemplateResource.new(@templates).serialize
  end

  # GET /templates/1
  def show
    render json: TemplateResource.new(@template).serialize
  end

  # POST /templates
  def create
    @template = Template.new(template_params)

    @template.environment = @environment
    @template.account = @environment.account

    if @template.save
      Analytics.track("template_created", account: @template.account, user: current_user,
                      properties: { template_id: @template.id })
      render json: TemplateResource.new(@template).serialize, status: :created, location: @template
    else
      render json: @template.errors.full_messages, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /templates/1
  def update
    if @template.update(template_params)
      render json: TemplateResource.new(@template).serialize
    else
      render json: @template.errors, status: :unprocessable_entity
    end
  end

  # DELETE /templates/1
  def destroy
    @template.destroy!
  end

  # POST /templates/1/render — preview without sending. Missing variables render
  # empty and are listed; unsubscribe_url is a placeholder.
  def render_preview
    data = params[:data].is_a?(ActionController::Parameters) ? params[:data].to_unsafe_h : {}
    renderer = TemplateRenderer.new(template: @template, variables: data.merge("unsubscribe_url" => TemplateRenderer::PREVIEW_UNSUBSCRIBE_URL))
    result = renderer.call

    render json: {
      subject: result.subject,
      preview: result.preview,
      content_html: result.content,
      html: result.body,
      layout_id: @template.layout_id,
      sending_identity: @template.sending_identity&.slice(:id, :from_name, :from_email),
      attachments: @template.attachments_summary,
      missing_variables: renderer.missing_variables
    }
  end

  # POST /templates/1/send_test — sends one rendered copy, marked [TEST], through
  # the same TemplateRenderer path as real sends. Merge data comes from the chosen
  # customer's liquid_variables (plus any `data`); `to` defaults to the signed-in
  # user. The message carries no drip/campaign ids, so it never counts in stats.
  # Drip steps pass the drip's sending_identity_id.
  def send_test
    return render json: { error: "Test send is only available for email templates" }, status: :unprocessable_entity unless @template.channel == "email"

    customer = @template.account.customers.find_by(id: params[:customer_id]) if params[:customer_id].present?
    return render json: { error: "Customer not found" }, status: :not_found if params[:customer_id].present? && !customer

    to = params[:to].presence || current_user&.email
    return render json: { error: "to is required" }, status: :unprocessable_entity if to.blank?

    data = params[:data].is_a?(ActionController::Parameters) ? params[:data].to_unsafe_h : {}
    # ponytail: the campaign test-unsubscribe page, so clicking it in a test never unsubscribes anyone.
    unsubscribe_url = "#{@template.account.tracking_base_url}/campaign_track/test_unsubscribe?email=#{CGI.escape(to)}&channel=email&campaign=#{CGI.escape(@template.name.to_s)}"
    vars = (customer&.liquid_variables || {}).merge(data).merge("unsubscribe_url" => unsubscribe_url)
    rendered = TemplateRenderer.call(template: @template, variables: vars)

    message = EmailMessage.new(
      account: @template.account,
      environment: @template.environment,
      template: @template,
      sending_identity_id: params[:sending_identity_id].presence || @template.sending_identity_id,
      to: to,
      subject: "[TEST] #{rendered.subject}",
      body: rendered.body,
      status: :pending
    )
    message.attachments.attach(@template.attachments.map(&:blob)) if @template.attachments.attached?
    message.save!

    DeliverMessageJob.perform_now(message)

    render json: { message: "Test email sent to #{to}", message_id: message.id }
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.record.errors.full_messages.to_sentence }, status: :unprocessable_entity
  end

  # POST /templates/1/attachments (multipart `file`)
  def add_attachment
    return render json: { error: "file is required" }, status: :unprocessable_entity unless params[:file].respond_to?(:read)

    @template.attachments.attach(params[:file])
    render json: TemplateResource.new(@template.reload).serialize, status: :created
  end

  # DELETE /templates/1/attachments/:attachment_id
  def remove_attachment
    @template.attachments.find(params[:attachment_id]).purge
    render json: TemplateResource.new(@template.reload).serialize
  end

  private
    # Only allow a list of trusted parameters through.
    def template_params
      permitted = [:name, :trigger, :subject, :body, :body_format, :preview, :folder_id, :layout_id, :sending_identity_id]
      permitted << :channel if action_name == "create"
      params.require(:template).permit(permitted)
    end
end
