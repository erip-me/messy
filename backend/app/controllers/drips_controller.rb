class DripsController < ApplicationController
  include ApiAuthentication

  before_action :set_drip, only: [:show, :update, :destroy, :activate, :pause]

  def index
    # Env-scoped so the dashboard's environment selector filters the list
    # (drips are environment-specific, like campaigns/templates).
    scope = @environment ? @account.drip_campaigns.where(environment_id: @environment.id) : @account.drip_campaigns
    drips = scope.includes(:segment, drip_steps: :template).order(created_at: :desc).to_a

    # Batch the per-drip aggregates into two grouped queries instead of running
    # exec_counts + enrollment stats once per drip (2N -> 2).
    step_ids = drips.flat_map(&:ordered_steps).map(&:id)
    exec_counts = DripStepExecution.where(drip_step_id: step_ids).group(:drip_step_id, :status).count
    enrollment_counts = DripEnrollment.where(drip_campaign_id: drips.map(&:id))
                                      .group(:drip_campaign_id, :status).count

    render json: DripResource.new(drips, params: { exec_counts: exec_counts, enrollment_counts: enrollment_counts }).serialize
  end

  def show
    render json: DripResource.new(@drip).serialize
  end

  def create
    drip = @account.drip_campaigns.new(drip_params)
    drip.environment_id ||= request.headers["X-Environment-Id"].presence || @environment&.id
    ActiveRecord::Base.transaction do
      drip.save!
      sync_steps!(drip)
    end
    render json: DripResource.new(drip.reload).serialize, status: :created
  rescue ActiveRecord::RecordInvalid => e
    render json: { errors: e.record.errors.full_messages }, status: :unprocessable_entity
  end

  def update
    ActiveRecord::Base.transaction do
      @drip.update!(drip_params)
      sync_steps!(@drip) if params.key?(:steps)
    end
    render json: DripResource.new(@drip.reload).serialize
  rescue ActiveRecord::RecordInvalid => e
    render json: { errors: e.record.errors.full_messages }, status: :unprocessable_entity
  end

  def destroy
    @drip.destroy
    render json: { message: "Drip deleted" }
  end

  def activate
    return render json: { error: "Add at least one step before activating" }, status: :unprocessable_entity if @drip.drip_steps.empty?

    missing = email_steps_missing_unsubscribe(@drip)
    if missing.any?
      return render json: { error: "Email steps #{missing.join(', ')} must include an {{unsubscribe_url}} link" }, status: :unprocessable_entity
    end

    @drip.update!(status: "active")
    DripBackfillJob.perform_later(@drip.id) if @drip.enroll_existing_on_start
    Analytics.track("drip_activated", account: @account, user: current_user,
                    properties: { drip_id: @drip.id, steps: @drip.drip_steps.count, segment_id: @drip.segment_id })
    render json: DripResource.new(@drip).serialize
  end

  # POST /drips/projection — estimate how many customers hit each step, using the
  # (possibly unsaved) segment + steps the designer currently has.
  def projection
    segment = @account.segments.find_by(id: params[:segment_id])
    steps = Array(params[:steps]).map do |s|
      { conditions: SegmentConditions.permit(s[:conditions]), on_fail: s[:on_fail].presence || "skip", channel: s[:channel].presence || "email" }
    end
    render json: DripProjectionService.new(@account, segment, steps).call
  end

  def pause
    @drip.update!(status: "paused")
    render json: DripResource.new(@drip).serialize
  end

  private

  def set_drip
    @drip = @account.drip_campaigns.find_by(id: params[:id])
    render json: { error: "Not found" }, status: :not_found unless @drip
  end

  # Positions (1-based) of email steps whose template lacks an unsubscribe link.
  # The link may live in the template body or in its layout (e.g. a shared
  # footer), so check both — the rendered email includes the layout.
  def email_steps_missing_unsubscribe(drip)
    drip.ordered_steps.each_with_index.filter_map do |step, i|
      channel = step.channel.presence || step.template&.channel
      next unless channel == "email"
      body = step.template&.body.to_s + step.template&.layout&.body.to_s
      next if body.include?("{{unsubscribe_url}}") || body.include?("{{ unsubscribe_url }}")
      i + 1
    end
  end

  def drip_params
    params.permit(:name, :segment_id, :environment_id, :allow_reentry, :exit_on_segment_leave, :enroll_existing_on_start, :sending_identity_id)
  end

  # Upsert steps by position; remove steps no longer present that have never run.
  def sync_steps!(drip)
    return unless params[:steps].is_a?(Array)

    incoming = params[:steps].each_with_index.map { |s, i| step_attrs(s, i) }
    keep_positions = incoming.map { |s| s[:position] }

    drip.drip_steps.where.not(position: keep_positions).find_each do |step|
      step.destroy unless step.drip_step_executions.exists?
    end

    incoming.each do |attrs|
      step = drip.drip_steps.find_or_initialize_by(position: attrs[:position])
      step.assign_attributes(attrs.merge(account_id: drip.account_id))
      step.save!
    end
  end

  def step_attrs(step, index)
    {
      position: (step[:position] || index).to_i,
      template_id: step[:template_id],
      channel: step[:channel].presence || "email",
      delay_days: (step[:delay_days] || 0).to_i,
      on_fail: step[:on_fail].presence || "skip",
      conditions: SegmentConditions.permit(step[:conditions])
    }
  end

end
