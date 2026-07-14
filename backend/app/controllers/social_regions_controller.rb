# Manage the markets a social content calendar is organised around, and the Meta
# publishing target (credential + Page / Instagram / ad account) for each. Reading
# is open to all signed-in users; managing is account-admin gated.
class SocialRegionsController < ApplicationController
  before_action :authenticate_user!
  before_action :require_account_admin!, only: %i[create update destroy]
  before_action :set_account
  before_action :set_region, only: %i[show update destroy]

  # GET /social_regions
  def index
    render json: @account.social_regions.includes(:integration, :linkedin_integration).order(:name).map { |r| SocialRegionResource.new(r).to_h }
  end

  # GET /social_regions/1
  def show
    render json: SocialRegionResource.new(@region).to_h
  end

  # POST /social_regions
  def create
    region = @account.social_regions.new(region_params)
    if region.save
      render json: SocialRegionResource.new(region).to_h, status: :created
    else
      render json: { errors: region.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # PATCH /social_regions/1
  def update
    if @region.update(region_params)
      render json: SocialRegionResource.new(@region).to_h
    else
      render json: { errors: @region.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # DELETE /social_regions/1
  def destroy
    @region.destroy!
    head :no_content
  end

  private

  def set_account
    @account = current_user.account
  end

  def set_region
    @region = @account.social_regions.find(params[:id])
  end

  def region_params
    params.require(:social_region).permit(
      :name, :timezone, :post_hour, :active, :environment_id,
      :integration_id, :page_id, :page_name, :ig_business_account_id, :ig_username, :ig_page_id, :ad_account_id,
      :linkedin_integration_id, :linkedin_org_id, :linkedin_org_name,
      :post_to_facebook, :post_to_instagram, :post_to_linkedin, countries: [], hashtags: []
    )
  end

end
