# Handles the provider redirect back from the Gmail / Office365 consent screen.
# Unauthenticated on purpose: the browser arrives here straight from Google /
# Microsoft with no app session, so trust is established by the signed `state`
# JWT that MailboxesController#oauth_url minted. On success it stores the tokens,
# best-effort registers cloud push, and redirects the user back to the helpdesk.
class MailboxOauthController < ApplicationController
  include OauthCallback

  def google_callback
    handle(:gmail, MailboxOauth::Google)
  end

  def microsoft_callback
    handle(:office365, MailboxOauth::Microsoft)
  end

  private

  def handle(provider, mod)
    return redirect_to_helpdesk(error: params[:error]) if params[:error].present?

    mailbox = mailbox_from_state
    return redirect_to_helpdesk(error: "invalid_state") unless mailbox && mailbox.provider == provider.to_s

    store_oauth_tokens!(mailbox, mod)
    setup_push(mailbox)

    redirect_to_helpdesk(connected: provider)
  rescue => e
    Rails.logger.error "[MailboxOauth] #{provider} callback failed: #{e.class} #{e.message}"
    redirect_to_helpdesk(error: "oauth_failed")
  end

  # Best-effort: a mailbox that can't register push still works via polling, so a
  # push failure (e.g. unreachable API_URL in non-prod) must not fail the connect.
  def setup_push(mailbox)
    mailbox.push_service&.start!
  rescue => e
    Rails.logger.warn "[MailboxOauth] push setup failed for mailbox #{mailbox.id}: #{e.message}"
  end

  def mailbox_from_state
    payload = oauth_state_payload
    Mailbox.find_by(id: payload && payload["mailbox_id"])
  end

  def redirect_to_helpdesk(**query)
    redirect_to_frontend("/helpdesk?tab=mailboxes", **query)
  end
end
