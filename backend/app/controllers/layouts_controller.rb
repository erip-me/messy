class LayoutsController < ApplicationController
  include ApiAuthentication
  wrap_parameters :layout, include: [:name, :body, :transformers]

  rescue_from ActiveRecord::RecordNotFound, with: :render_404

  before_action :load_layout, only: %i[ show update destroy ]

  # GET /layouts
  def index
    @layouts = @environment.layouts.all

    render json: LayoutResource.new(@layouts).serialize
  end

  # GET /layouts/1
  def show
    render json: LayoutResource.new(@layout).serialize
  end

  # POST /layouts
  def create
    @layout = Layout.new(layout_params)

    @layout.environment = @environment
    @layout.account = @environment.account

    if @layout.save
      render json: LayoutResource.new(@layout).serialize, status: :created, location: @layout
    else
      render json: @layout.errors.full_messages, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /layouts/1
  def update
    if @layout.update(layout_params)
      render json: LayoutResource.new(@layout).serialize
    else
      render json: @layout.errors, status: :unprocessable_entity
    end
  end

  # DELETE /layouts/1
  def destroy
    @layout.destroy!
  end

  private

  def load_layout
    @layout = Layout.where(account_id: @account.id).find(params[:id])
  end

  def layout_params
    permitted = params.require(:layout).permit(:name, :body)
    transformers_param = params[:layout][:transformers] || params[:transformers]
    if transformers_param.present?
      permitted[:transformers] = transformers_param.permit(
        :heading, :paragraph, :link, :image, :strong, :em,
        :list, :listitem, :blockquote, :hr, :codespan
      ).to_h
    end
    permitted
  end
end
