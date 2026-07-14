# The per-region content calendar + day detail. Operators review a day's
# alternatives, pick which creative fills the feed and/or reel slot (mix-and-match
# across variants), edit copy, mark the day ready, and can publish now / retry.
# Ready days are auto-posted by PublishScheduledSocialPostsJob. Open to all
# signed-in users; every query is scoped to the current account's regions.
class SocialPostsController < ApplicationController

  before_action :authenticate_user!
  before_action :set_account
  before_action :set_region, only: %i[calendar create]
  before_action :set_post, only: %i[show update create_alternative publish_now deliveries]

  # GET /social_regions/:region_id/calendar?month=YYYY-MM
  def calendar
    month = parse_month(params[:month])
    posts = @region.social_posts.in_month(month)
      .includes(:social_post_deliveries, social_alternatives: { feed_media_attachment: :blob, reel_media_attachment: :blob }).to_a

    render json: {
      region: SocialRegionSummaryResource.new(@region).to_h,
      month: month.strftime("%Y-%m"),
      today: @region.local_today,
      posts: SocialPostSummaryResource.new(posts).to_h
    }
  end

  # GET /social_posts/:id
  def show
    render json: SocialPostDetailResource.new(@post).to_h
  end

  # POST /social_regions/:region_id/social_posts { date } — create/return an empty day.
  def create
    date = parse_date(params[:date])
    return render json: { error: "A valid date is required" }, status: :unprocessable_entity unless date

    post = @region.social_posts.find_or_create_by!(post_date: date)
    render json: SocialPostDetailResource.new(post).to_h, status: :created
  end

  # PATCH /social_posts/:id — set feed/reel slot selections and/or mark ready.
  def update
    assign_slot(:feed_alternative_id, params[:feed_alternative_id]) if params.key?(:feed_alternative_id)
    assign_slot(:reel_alternative_id, params[:reel_alternative_id]) if params.key?(:reel_alternative_id)
    assign_slot(:carousel_alternative_id, params[:carousel_alternative_id]) if params.key?(:carousel_alternative_id)
    @post.post_hour = params[:post_hour].presence if params.key?(:post_hour) # nil clears the override

    if params.key?(:ready)
      if ActiveModel::Type::Boolean.new.cast(params[:ready])
        return render json: { error: "You can't ready a day in the past" }, status: :unprocessable_entity if @post.past?
        return render json: { error: "Pick a creative with an image or video first" }, status: :unprocessable_entity unless @post.publishable_media?

        @post.status = :ready
      else
        @post.status = :pending
      end
    end

    @post.save!
    render json: SocialPostDetailResource.new(@post).to_h
  end

  # POST /social_posts/:id/alternatives — manual upload (image or video).
  def create_alternative
    alt = @post.social_alternatives.create!(
      source: :manual,
      position: (@post.social_alternatives.maximum(:position) || -1) + 1,
      headline: params[:headline], body: params[:body],
      cta_label: params[:cta_label], cta_url: params[:cta_url]
    )
    alt.feed_media.attach(params[:feed_media]) if params[:feed_media].present?
    alt.reel_media.attach(params[:reel_media]) if params[:reel_media].present?
    Array(params[:carousel_media]).compact_blank.each { |file| alt.carousel_media.attach(file) }
    render json: SocialPostDetailResource.new(@post.reload).to_h, status: :created
  end

  # POST /social_posts/:id/publish_now — manual publish/retry for today's ready-or-failed day.
  def publish_now
    return render json: { error: "Only today's posts can be published" }, status: :unprocessable_entity unless @post.postable_today?
    return render json: { error: "Nothing with an image or video is selected to publish" }, status: :unprocessable_entity unless @post.publishable_media?

    PublishSocialPostJob.perform_later(@post.id)
    render json: SocialPostDetailResource.new(@post).to_h
  end

  # GET /social_posts/:id/deliveries — the posting log for this day.
  def deliveries
    render json: @post.social_post_deliveries.includes(:integration).recent.map(&:as_log_json)
  end

  private

  def set_account
    @account = current_user.account
  end

  def set_region
    @region = @account.social_regions.find(params[:region_id])
  end

  def set_post
    @post = SocialPost.joins(:social_region)
      .where(social_regions: { account_id: @account.id }).find(params[:id])
  end

  # Resolve an alternative id (or null/blank) on THIS post and assign it to the
  # given slot, rejecting ids that aren't part of the day.
  def assign_slot(column, value)
    if value.blank?
      @post[column] = nil
      return
    end

    alt = @post.social_alternatives.find_by(id: value)
    raise ActiveRecord::RecordNotFound, "Alternative #{value} not on this post" unless alt

    @post[column] = alt.id
  end

  def parse_month(str)
    Date.strptime(str.to_s, "%Y-%m")
  rescue ArgumentError, TypeError
    Date.current.beginning_of_month
  end

  def parse_date(str)
    Date.iso8601(str.to_s)
  rescue ArgumentError, TypeError
    nil
  end
end
