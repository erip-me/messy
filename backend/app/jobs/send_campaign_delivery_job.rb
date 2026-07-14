class SendCampaignDeliveryJob < ApplicationJob
  include CampaignLinkSigner

  queue_as :campaigns

  RateLimitError = Class.new(StandardError)

  retry_on RateLimitError, wait: :polynomially_longer, attempts: 10 do |job, error|
    delivery = CampaignDelivery.find_by(id: job.arguments.first)
    delivery&.update!(status: 'failed', error_message: "Rate limit exceeded after retries: #{error.message}")
  end
  retry_on StandardError, wait: 30.seconds, attempts: 3

  def perform(delivery_id)
    delivery = CampaignDelivery
      .includes(campaign: [:template, :environment, :account])
      .find_by(id: delivery_id)
    return unless delivery && delivery.status == 'pending'

    @tracking_base_url = delivery.campaign.account.tracking_base_url

    campaign = delivery.campaign
    customer = delivery.customer
    rendered_content = render_content(campaign, customer, delivery)

    if campaign.channel == 'email'
      deliver_email(campaign, delivery, rendered_content)
    else
      deliver_via_integration(campaign, delivery, customer, rendered_content)
    end

    delivery.update!(status: 'sent', sent_at: Time.current)
    delivery.log_activity!('campaign_sent', channel: campaign.channel)
  rescue RateLimitError
    raise
  rescue => e
    raise RateLimitError, e.message if rate_limit_error?(e)
    delivery&.update!(status: 'failed', error_message: e.message) rescue nil
    raise e
  end

  private

  def render_content(campaign, customer, delivery)
    content = campaign.template ? campaign.template.body : campaign.content.to_s
    unsubscribe_url = "#{@tracking_base_url}/campaign_track/#{delivery.tracking_token}/unsubscribe"

    variables = (customer&.liquid_variables || {}).merge('unsubscribe_url' => unsubscribe_url)

    Liquid::Template.parse(content).render(variables)
  end

  def deliver_email(campaign, delivery, rendered_content)
    integration = campaign.channel_integration
    raise "No email integration configured" unless integration

    processed_html = process_html(rendered_content, delivery.tracking_token)
    unsubscribe_url = "#{@tracking_base_url}/campaign_track/#{delivery.tracking_token}/unsubscribe"

    # Inject tracking pixel
    tracking_pixel = %(<img src="#{@tracking_base_url}/campaign_track/#{delivery.tracking_token}/open.png" width="1" height="1" alt="" style="display:none;border:0;outline:none;">)
    tracked_html = processed_html + tracking_pixel

    message = CampaignEmailMessage.new(
      to: delivery.email,
      subject: campaign.subject,
      html: tracked_html
    )
    from_line = SendingIdentity.from_line(campaign.sending_identity, campaign.account)
    from_line ? integration.deliver!(message, from: from_line) : integration.deliver!(message)
  end

  def deliver_via_integration(campaign, delivery, customer, rendered_content)
    integration = campaign.channel_integration
    raise "No #{campaign.channel} integration configured" unless integration

    adapter = CampaignMessageAdapter.new(
      campaign: campaign,
      delivery: delivery,
      customer: customer,
      rendered_content: rendered_content
    )

    integration.deliver!(adapter)
  end

  def rate_limit_error?(error)
    error.message.match?(/rate.*(exceeded|limit)|throttl|too.many.requests|429/i)
  end

  def process_html(html, token)
    TrackingLinkRewriter.call(
      html,
      base: @tracking_base_url,
      token: token,
      path: "campaign_track",
      sign: ->(url) { campaign_link_signature(url) }
    )
  end

end
