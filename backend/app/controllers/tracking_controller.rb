class TrackingController < ApplicationController
  include TrackingLinkSigner

  def pixel
    token = params[:token].to_s.sub(/\.png\z/, '')
    message = Message.find_by(tracking_token: token)
    
    if message
      begin
        # Track the open
        Open.track_open(message, request)
      rescue => e
        # Log the error but don't fail the request
        Rails.logger.error "Failed to track email open for message #{message.id}: #{e.message}"
      end
    end

    # Always return a 1x1 transparent PNG regardless of whether tracking succeeded
    # This prevents email clients from showing broken images
    render_tracking_pixel
  end

  # GET /track/:token/click — records a click on a transactional message and
  # redirects to the original URL. Mirrors CampaignTrackingController#click.
  def click
    target = params[:url].to_s
    # Only follow URLs we signed when generating the link. An unsigned/forged
    # url param falls back to the app root instead of acting as an open redirect.
    signed = valid_tracking_link?(target, params[:sig], Message::CLICK_SIGNATURE_PURPOSE)

    if signed
      message = Message.find_by(tracking_token: params[:token])
      if message
        begin
          Click.track_click(message, target, request)
        rescue => e
          # Log the error but don't fail the redirect
          Rails.logger.error "Failed to track email click for message #{message.id}: #{e.message}"
        end
      end
      redirect_to target, allow_other_host: true
    else
      redirect_to '/', allow_other_host: false
    end
  end

  # GET /track/:token/unsubscribe — public unsubscribe link for a transactional
  # message (e.g. a drip step). Resolves the recipient + channel from the message
  # and unsubscribes them from that channel.
  def unsubscribe
    message = Message.find_by(tracking_token: params[:token])
    if message
      channel = message.type.to_s.sub("Message", "").underscore
      customer = message.account.customers.find_by(email: message.to) ||
                 message.account.customers.find_by(phone: message.to)
      # A drip (marketing) message opts the customer out of marketing only, so
      # system/transactional messages keep flowing. Other messages fall back to
      # the legacy hard channel unsubscribe.
      if message.drip_campaign_id
        customer&.unsubscribe_from_category!(Customer::MARKETING_CATEGORY)
      else
        customer&.unsubscribe_from!(channel)
      end
    end

    render html: "<html><body style=\"font-family:sans-serif;text-align:center;padding:48px\">" \
                 "<h2>You've been unsubscribed</h2>" \
                 "<p>You won't receive further messages on this channel.</p></body></html>".html_safe
  end

  private

  def render_tracking_pixel
    # 1x1 transparent PNG in base64
    pixel_data = Base64.decode64('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==')
    
    send_data pixel_data,
      type: 'image/png',
      disposition: 'inline',
      cache_control: 'no-store, no-cache, must-revalidate, max-age=0',
      pragma: 'no-cache',
      expires: 'Thu, 01 Jan 1970 00:00:00 GMT'
  end
end