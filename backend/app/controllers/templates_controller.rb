class TemplatesController < ApplicationController
  include ApiAuthentication

  before_action :load_template, only: %i[ show update destroy render_preview add_attachment remove_attachment ]

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
