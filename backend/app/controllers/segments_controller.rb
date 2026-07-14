class SegmentsController < ApplicationController
  # Accepts either an environment API key or a dashboard JWT (see
  # CampaignsController). Lets clients read/create segments programmatically —
  # e.g. to look up the segment a launch campaign targeted before duplicating it.
  include ApiAuthentication
  before_action :set_segment, only: [:show, :update, :destroy, :clean]

  def index
    segments = @account.segments.order(created_at: :desc)
    render json: SegmentResource.new(segments).serialize
  end

  def show
    if @segment.cleanup_status == "in_progress" && @segment.updated_at < 5.minutes.ago
      @segment.update_columns(cleanup_status: "failed", cleanup_stats: { error: "Job was interrupted" })
    end
    render json: SegmentResource.new(@segment).serialize
  end

  def create
    segment = @account.segments.new(segment_params)
    if segment.save
      count = SegmentEvaluator.new(@account.customers, segment.conditions).count
      segment.update_column(:customer_count, count)
      Analytics.track("segment_created", account: @account, user: current_user,
                      properties: { segment_id: segment.id, customer_count: count })
      render json: SegmentResource.new(segment).serialize, status: :created
    else
      render json: { errors: segment.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update
    if @segment.update(segment_params)
      count = SegmentEvaluator.new(@account.customers, @segment.conditions).count
      @segment.update_column(:customer_count, count)
      render json: SegmentResource.new(@segment).serialize
    else
      render json: { errors: @segment.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    @segment.destroy
    render json: { message: 'Segment deleted' }
  end

  # POST /segments/preview — evaluate conditions without saving
  def preview
    conditions = SegmentConditions.permit(params[:conditions])
    scope = SegmentEvaluator.new(@account.customers, conditions).evaluate
    count = scope.count
    sample = scope.order(created_at: :desc).limit(5)
    render json: { count: count, sample: sample }
  end

  # POST /segments/:id/clean — start list cleanup job
  def clean
    if @segment.cleanup_status == "in_progress" && @segment.updated_at > 5.minutes.ago
      render json: { error: "A cleanup is already in progress for this segment." }, status: :unprocessable_entity
      return
    end

    ListCleanupJob.perform_later(@segment.id, current_user&.id)
    render json: { message: 'List cleanup started. You will receive an email when it completes.' }
  end

  # GET /segments/attributes — list available condition attributes
  def attributes
    system_attrs = [
      { key: "email",      label: "Email",      type: "string" },
      { key: "first_name", label: "First Name", type: "string" },
      { key: "last_name",  label: "Last Name",  type: "string" },
      { key: "created_at", label: "Date Added", type: "date"   },
    ]
    # DISTINCT server-side so we don't stream one row per key per customer into
    # Ruby just to de-dupe it. Still a scan; a materialized keys set is the next
    # step if this account's customer table grows large.
    custom_keys = @account.customers
                    .pluck(Arel.sql("DISTINCT jsonb_object_keys(custom_attributes)"))
                    .sort
    custom_attrs = custom_keys.map { |k| { key: "custom.#{k}", label: k, type: "string" } }
    render json: { attributes: system_attrs + custom_attrs }
  end

  private

  def set_segment
    @segment = @account.segments.find(params[:id])
  end

  def segment_params
    params.permit(:name, :description).tap do |p|
      p[:conditions] = SegmentConditions.permit(params[:conditions]) if params.key?(:conditions)
    end
  end
end
