# LinkedIn OAuth + discovery for a LinkedIn social credential: mints the consent
# URL to connect it, and lists the Organization pages the connected member can
# publish to, to populate a region's target dropdown. Admin-gated like region
# management.
class LinkedinDiscoveryController < ApplicationController
  before_action :authenticate_user!
  before_action :require_account_admin!
  before_action :set_integration

  # GET /integrations/:id/linkedin/oauth_url — the consent URL to redirect to.
  # State is a signed JWT so the (unauthenticated) callback can trust which
  # integration it's connecting.
  def oauth_url
    unless SocialOauth::Linkedin.configured?
      return render json: { error: "LinkedIn OAuth is not configured on this server" }, status: :unprocessable_entity
    end

    state = JWT.encode(
      { integration_id: @integration.id, exp: 15.minutes.from_now.to_i },
      Rails.application.secret_key_base,
      "HS256"
    )
    render json: { url: SocialOauth::Linkedin.authorize_url(state) }
  end

  # GET /integrations/:id/linkedin/organizations — pages the member administers.
  def organizations
    render json: @integration.organizations
  end

  private

  def set_integration
    @integration = current_user.account.integrations.find(params[:id])
    return if @integration.is_a?(LinkedinSocialIntegration)

    render json: { error: "Not a LinkedIn integration" }, status: :unprocessable_entity
  end
end
