class TemplatesController < ApplicationController
  include ApiAuthentication

  before_action :load_template, only: %i[ show update destroy ]

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

  private
    # Only allow a list of trusted parameters through.
    def template_params
      permitted = [:name, :trigger, :subject, :body, :body_format, :preview, :folder_id, :layout_id]
      permitted << :channel if action_name == "create"
      params.require(:template).permit(permitted)
    end
end
