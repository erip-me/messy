class CampaignTrackingController < ApplicationController
  include CampaignLinkSigner

  skip_before_action :authenticate_user!, raise: false

  TRANSPARENT_GIF = Base64.decode64(
    'R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7'
  ).freeze

  def open
    delivery = CampaignDelivery.find_by(tracking_token: params[:token])
    if delivery
      CampaignDelivery.where(id: delivery.id, opened_at: nil).update_all(opened_at: Time.current)
      CampaignDelivery.where(id: delivery.id).update_all('open_count = open_count + 1')
      delivery.log_activity!('campaign_opened')
    end
    send_data TRANSPARENT_GIF,
              type: 'image/gif',
              disposition: 'inline',
              filename: 'open.gif'
  end

  def click
    delivery = CampaignDelivery.find_by(tracking_token: params[:token])
    if delivery
      CampaignDelivery.where(id: delivery.id).update_all('click_count = click_count + 1')
      delivery.log_activity!('campaign_clicked', url: params[:url])
    end

    # Only follow URLs we signed when generating the link. An unsigned/forged
    # url param falls back to the app root instead of acting as an open redirect.
    target = params[:url].to_s
    if valid_campaign_link?(target, params[:sig])
      redirect_to target, allow_other_host: true
    else
      redirect_to '/', allow_other_host: false
    end
  end

  def unsubscribe
    delivery = CampaignDelivery.includes(:customer, :campaign).find_by(tracking_token: params[:token])
    if delivery&.customer
      channel = delivery.campaign.channel
      # Opt out of marketing (drips + campaigns), not the whole channel, so
      # transactional/system messages keep flowing.
      #
      # Log the unsubscribe only on the actual subscribed -> unsubscribed
      # transition: email scanners/prefetchers and repeat clicks hit this link
      # several times, and logging every hit inflated the campaign's count.
      was_subscribed = !delivery.customer.unsubscribed_from_category?(Customer::MARKETING_CATEGORY)
      delivery.customer.unsubscribe_from_category!(Customer::MARKETING_CATEGORY)
      delivery.log_activity!('campaign_unsubscribed', channel: channel) if was_subscribed
    end
    render html: branded_page(
      title: "You've been unsubscribed",
      message: "You will no longer receive marketing messages from this sender.",
      campaign_name: delivery&.campaign&.name,
      token: params[:token],
      show_resubscribe: true
    ).html_safe, layout: false
  end

  def resubscribe
    delivery = CampaignDelivery.includes(:customer, :campaign).find_by(tracking_token: params[:token])
    if delivery&.customer
      channel = delivery.campaign.channel
      delivery.customer.resubscribe_to_category!(Customer::MARKETING_CATEGORY)
      delivery.log_activity!('campaign_resubscribed', channel: channel)
    end
    render html: branded_page(
      title: "You've been resubscribed",
      message: "You will continue receiving marketing messages from this sender.",
      campaign_name: delivery&.campaign&.name,
      token: nil,
      show_resubscribe: false
    ).html_safe, layout: false
  end

  def test_unsubscribe
    email = params[:email]
    channel = params[:channel]
    campaign_name = params[:campaign]
    render html: branded_page(
      title: "Test Unsubscribe Link",
      message: "This is a <strong>test</strong> unsubscribe link. No action was taken.<br><br>" \
               "Customer: <strong>#{ERB::Util.html_escape(email)}</strong><br>" \
               "Channel: <strong>#{ERB::Util.html_escape(channel)}</strong>",
      campaign_name: campaign_name,
      token: nil,
      show_resubscribe: false
    ).html_safe, layout: false
  end

  private

  def branded_page(title:, message:, campaign_name: nil, token: nil, show_resubscribe: false)
    resubscribe_button = if show_resubscribe && token
      <<~BTN
        <form method="post" action="/campaign_track/#{ERB::Util.html_escape(token)}/resubscribe" style="margin-top: 24px;">
          <button type="submit" style="display:inline-block;padding:10px 24px;font-size:14px;font-family:'Inter',-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif;color:#3b82f6;background:#ffffff;border:2px solid #3b82f6;border-radius:9999px;cursor:pointer;text-decoration:none;">
            Resubscribe
          </button>
        </form>
      BTN
    else
      ""
    end

    campaign_line = campaign_name ? %(<p style="margin:12px 0 0;font-size:13px;color:#94a3b8;">Campaign: #{ERB::Util.html_escape(campaign_name)}</p>) : ""

    <<~HTML
      <!DOCTYPE html>
      <html>
      <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title>#{ERB::Util.html_escape(title)}</title>
      </head>
      <body style="margin:0;padding:0;background-color:#f1f5f9;font-family:'Inter',-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif;">
        <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background-color:#f1f5f9;padding:60px 20px;min-height:100vh;">
          <tr>
            <td align="center" valign="top">
              <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="max-width:480px;background-color:#ffffff;border-radius:16px;overflow:hidden;box-shadow:0 1px 2px rgba(15,23,42,0.04), 0 4px 16px rgba(15,23,42,0.06);">
                <tr>
                  <td style="background:linear-gradient(135deg,#3b82f6,#6366f1);padding:24px 32px;text-align:center;">
                    <span style="font-family:'Inter',-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif;font-size:22px;font-weight:800;color:#ffffff;letter-spacing:-0.02em;">Messy</span>
                  </td>
                </tr>
                <tr>
                  <td style="padding:40px 32px;text-align:center;">
                    <h1 style="margin:0 0 12px;font-size:20px;font-weight:600;color:#0f172a;">#{ERB::Util.html_escape(title)}</h1>
                    <p style="margin:0;font-size:15px;color:#64748b;line-height:1.6;">#{message}</p>
                    #{campaign_line}
                    #{resubscribe_button}
                  </td>
                </tr>
                <tr>
                  <td style="padding:20px 32px 24px;border-top:1px solid #e2e8f0;">
                    <p style="margin:0;font-size:12px;color:#94a3b8;text-align:center;line-height:1.6;">
                      Sent by Messy &middot; Messaging Platform<br>
                      &copy; #{Date.today.year} Tuli Technologies
                    </p>
                  </td>
                </tr>
              </table>
            </td>
          </tr>
        </table>
      </body>
      </html>
    HTML
  end
end
