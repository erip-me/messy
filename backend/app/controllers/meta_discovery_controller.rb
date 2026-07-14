# Graph-API discovery for a Meta credential (system-user token): lists the Pages,
# Instagram accounts, and ad accounts it can reach, to populate a region's target
# dropdowns. Admin-gated like region management.
class MetaDiscoveryController < ApplicationController
  before_action :authenticate_user!
  before_action :require_account_admin!
  before_action :set_integration

  # GET /integrations/:id/meta/pages
  def pages
    render json: @integration.pages
  end

  # GET /integrations/:id/meta/ad_accounts
  def ad_accounts
    render json: @integration.ad_accounts
  end

  # GET /integrations/:id/meta/instagram?page_id=
  def instagram
    render json: @integration.instagram_for_page(params[:page_id]) || {}
  end

  # GET /integrations/:id/meta/instagram_accounts
  def instagram_accounts
    render json: @integration.instagram_accounts
  end

  private

  def set_integration
    @integration = current_user.account.integrations.find(params[:id])
    return if @integration.is_a?(MetaSocialIntegration)

    render json: { error: "Not a Meta integration" }, status: :unprocessable_entity
  end
end
