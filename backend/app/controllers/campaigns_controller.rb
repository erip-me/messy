class CampaignsController < ApplicationController
  # Accepts either an environment API key or a dashboard JWT. `ApiAuthentication`
  # sets @account/@environment from whichever is presented, so campaigns can be
  # managed both from the Messy dashboard and programmatically (e.g. Lalaaji
  # duplicating a launch campaign for a new template).
  include ApiAuthentication
  before_action :set_campaign, only: [:show, :update, :destroy, :send_campaign, :send_test, :deliveries, :retry_delivery, :retry_all_failed]
  before_action :require_active_billing!, only: [:send_campaign]

  def index
    # Scope to the active environment so the dashboard's env selector actually
    # filters the list. Campaigns are account-owned but environment-specific;
    # without this, campaigns from every environment (incl. test) show under prd.
    scope = @environment ? @account.campaigns.where(environment_id: @environment.id) : @account.campaigns
    campaigns = scope.includes(:segment, :template).order(created_at: :desc).to_a
    stats_by_campaign = Campaign.stats_for(campaigns)
    render json: CampaignResource.new(campaigns, params: { stats_by_campaign: stats_by_campaign }).serialize
  end

  def show
    render json: CampaignResource.new(@campaign).serialize
  end

  def create
    campaign = @account.campaigns.new(campaign_params)
    campaign.environment_id ||= request.headers['X-Environment-Id'].presence || @environment&.id
    if campaign.save
      render json: CampaignResource.new(campaign).serialize, status: :created
    else
      render json: { errors: campaign.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update
    return render json: { error: 'Cannot edit a sent campaign' }, status: :unprocessable_entity if @campaign.status == 'sent'
    if @campaign.update(campaign_params)
      render json: CampaignResource.new(@campaign).serialize
    else
      render json: { errors: @campaign.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    return render json: { error: 'Cannot delete a sending campaign' }, status: :unprocessable_entity if @campaign.status == 'sending'
    @campaign.destroy
    render json: { message: 'Campaign deleted' }
  end

  def send_campaign
    return render json: { error: 'Campaign is not in draft status' }, status: :unprocessable_entity unless @campaign.status == 'draft'

    if @campaign.channel == 'email'
      content = @campaign.template ? @campaign.template.body : @campaign.content.to_s
      unless content.include?('{{unsubscribe_url}}') || content.include?('{{ unsubscribe_url }}')
        return render json: { error: 'Email campaigns must include an {{unsubscribe_url}} link' }, status: :unprocessable_entity
      end
    end

    @campaign.update!(status: 'sending')
    SendCampaignJob.perform_later(@campaign.id)
    Analytics.track("campaign_sent", account: @account, user: current_user,
                    properties: { campaign_id: @campaign.id, channel: @campaign.channel, segment_id: @campaign.segment_id })
    render json: { message: 'Campaign sending started', status: 'sending' }
  end

  def send_test
    return render json: { error: 'Test send is only available for email campaigns' }, status: :unprocessable_entity unless @campaign.channel == 'email'

    customer = @account.customers.find_by(id: params[:customer_id])
    return render json: { error: 'Customer not found' }, status: :not_found unless customer

    return render json: { error: 'No email integration configured for this campaign' }, status: :unprocessable_entity unless @campaign.channel_integration

    content = @campaign.template ? @campaign.template.body : @campaign.content.to_s
    tracking_base_url = @campaign.account.tracking_base_url
    test_unsubscribe_url = "#{tracking_base_url}/campaign_track/test_unsubscribe?email=#{CGI.escape(customer.email)}&channel=#{@campaign.channel}&campaign=#{CGI.escape(@campaign.name)}"
    variables = {
      'first_name' => customer.first_name.to_s,
      'last_name' => customer.last_name.to_s,
      'email' => customer.email.to_s,
      'unsubscribe_url' => test_unsubscribe_url
    }.merge(customer.custom_attributes.transform_values(&:to_s))
    rendered = Liquid::Template.parse(content).render(variables)

    message = EmailMessage.create!(
      account: @campaign.account,
      environment: @campaign.environment,
      to: customer.email,
      subject: "[TEST] #{@campaign.subject}",
      body: rendered,
      status: :pending
    )

    # Inject tracking pixel so we can detect opens on test sends
    message.update!(body: message.inject_tracking_pixel) if message.tracking_token.present?

    DeliverMessageJob.perform_now(message)

    render json: { message: "Test email sent to #{customer.email}", message_id: message.id }
  rescue => e
    render json: { error: "Failed to send test: #{e.message}" }, status: :unprocessable_entity
  end

  def retry_delivery
    delivery = @campaign.campaign_deliveries.find(params[:delivery_id])
    return render json: { error: 'Only failed deliveries can be retried' }, status: :unprocessable_entity unless delivery.status == 'failed'

    delivery.update!(status: 'pending', error_message: nil)
    SendCampaignDeliveryJob.perform_later(delivery.id)
    render json: { message: 'Delivery queued for retry' }
  end

  def retry_all_failed
    deliveries = @campaign.campaign_deliveries.where(status: 'failed')
    count = deliveries.count
    return render json: { error: 'No failed deliveries to retry' }, status: :unprocessable_entity if count.zero?

    deliveries.update_all(status: 'pending', error_message: nil)
    deliveries_to_retry = @campaign.campaign_deliveries.where(status: 'pending', sent_at: nil)
    jobs = deliveries_to_retry.pluck(:id).map { |id| SendCampaignDeliveryJob.new(id) }
    ActiveJob.perform_all_later(jobs)
    render json: { message: "#{count} deliveries queued for retry", count: count }
  end

  def deliveries
    deliveries = @campaign.campaign_deliveries.includes(:customer).order(created_at: :desc)
    if params[:status] == 'opened'
      deliveries = deliveries.where('open_count > 0')
    elsif params[:status] == 'unsubscribed'
      deliveries = deliveries.where(id: @campaign.unsubscribed_delivery_ids)
    elsif params[:status].present?
      deliveries = deliveries.where(status: params[:status])
    end
    total = deliveries.count
    deliveries = deliveries.page(params[:page] || 1).per(25)
    render json: {
      deliveries: CampaignDeliveryResource.new(deliveries).to_h,
      total: total,
      page: deliveries.current_page,
      total_pages: deliveries.total_pages
    }
  end

  private

  def set_campaign
    @campaign = @account.campaigns.find(params[:id])
  end

  def campaign_params
    params.permit(:name, :subject, :content, :segment_id, :channel, :template_id, :environment_id, :sending_identity_id)
  end
end
