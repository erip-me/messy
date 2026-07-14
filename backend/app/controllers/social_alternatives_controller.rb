# Edit / delete a day's creative variants, and ad-hoc "post now". Open to all
# signed-in users; scoped to the current account's regions.
class SocialAlternativesController < ApplicationController

  before_action :authenticate_user!
  before_action :set_account
  before_action :set_alternative

  # PATCH /social_alternatives/:id — edit the copy.
  def update
    @alternative.headline  = params[:headline]  if params.key?(:headline)
    @alternative.body      = params[:body]      if params.key?(:body)
    @alternative.cta_label = params[:cta_label] if params.key?(:cta_label)
    @alternative.cta_url   = params[:cta_url]   if params.key?(:cta_url)
    @alternative.save!
    render json: SocialPostDetailResource.new(@alternative.social_post).to_h
  end

  # DELETE /social_alternatives/:id — remove a variant (clears any slot it filled;
  # Active Storage purges its media).
  def destroy
    post = @alternative.social_post
    @alternative.destroy!
    render json: SocialPostDetailResource.new(post.reload).to_h
  end

  # POST /social_alternatives/:id/post_now — publish this one creative to every
  # channel now, without picking it or changing the day's status. Not restricted
  # to today (for one-offs / reposts from the archive).
  def post_now
    post = @alternative.social_post
    return render json: { error: "This region has no configured social account" }, status: :unprocessable_entity unless post.social_region.configured?

    slot = params[:slot].presence || (@alternative.feed_media.attached? ? "feed" : "reel")
    return render json: { error: "This variant has no media to post" }, status: :unprocessable_entity unless @alternative.media_for(slot)

    # Restrict an explicit pick to the channels this region can actually reach
    # (Facebook/Instagram and/or LinkedIn); nil falls back to the region default.
    channels = Array(params[:channels]).map(&:to_s) & post.social_region.available_channels
    channels = nil if channels.empty?
    PublishSocialAlternativeJob.perform_later(post.id, @alternative.id, slot, channels)
    render json: SocialPostDetailResource.new(post).to_h
  end

  private

  def set_account
    @account = current_user.account
  end

  def set_alternative
    @alternative = SocialAlternative.joins(social_post: :social_region)
      .where(social_regions: { account_id: @account.id }).find(params[:id])
  end
end
