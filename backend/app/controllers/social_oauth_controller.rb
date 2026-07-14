# Handles the provider redirect back from the LinkedIn consent screen.
# Unauthenticated on purpose: the browser arrives here straight from LinkedIn
# with no app session, so trust is established by the signed `state` JWT that
# LinkedinDiscoveryController#oauth_url minted. On success it stores the tokens
# on the integration and redirects the operator back to the Socials page.
class SocialOauthController < ApplicationController
  include OauthCallback

  def linkedin_callback
    return redirect_to_socials(error: params[:error]) if params[:error].present?

    integration = integration_from_state
    return redirect_to_socials(error: "invalid_state") unless integration.is_a?(LinkedinSocialIntegration)

    store_oauth_tokens!(integration, SocialOauth::Linkedin)

    redirect_to_socials(connected: "linkedin")
  rescue => e
    Rails.logger.error "[SocialOauth] linkedin callback failed: #{e.class} #{e.message}"
    redirect_to_socials(error: "oauth_failed")
  end

  private

  def integration_from_state
    payload = oauth_state_payload
    Integration.find_by(id: payload && payload["integration_id"])
  end

  def redirect_to_socials(**query)
    redirect_to_frontend("/socials", **query)
  end
end
