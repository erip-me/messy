# One region's content for one calendar date. Records which alternative's asset
# fills the feed slot and/or the reel slot (mix-and-match across variants). Becomes
# `ready` once at least one slot is picked; the scheduler posts it at the region's
# local post_hour and only ever on its own date — a past day is never posted, even
# if readied late. Per-target results are logged in social_post_deliveries.
class SocialPost < ApplicationRecord
  belongs_to :social_region
  belongs_to :feed_alternative, class_name: "SocialAlternative", optional: true
  belongs_to :reel_alternative, class_name: "SocialAlternative", optional: true
  belongs_to :carousel_alternative, class_name: "SocialAlternative", optional: true

  has_many :social_alternatives, dependent: :destroy
  has_many :social_post_deliveries, dependent: :destroy

  enum :status, { pending: 0, ready: 1, posted: 2, failed: 3, skipped: 4 }

  validates :post_date, presence: true, uniqueness: { scope: :social_region_id }
  validates :post_hour, inclusion: { in: 0..23 }, allow_nil: true
  # A post must carry imagery to go out — an all-text day would publish nothing
  # (every channel here requires a media URL), so block the transition into
  # `ready`. Only fires when status is *changing* to ready, so later edits of an
  # already-ready day (e.g. a post_hour tweak) aren't retroactively blocked.
  validate :must_have_media, if: -> { ready? && status_changed? }

  scope :in_month, ->(date) { where(post_date: date.beginning_of_month..date.end_of_month) }
  scope :ready_for, ->(date) { where(post_date: date, status: :ready) }

  delegate :account, :account_id, :local_today, to: :social_region

  # The region-local hour this day publishes at: the per-post override if set,
  # else the region's default post_hour.
  def effective_post_hour
    post_hour || social_region.post_hour
  end

  # Is this post's date today in its region's timezone? Publishing and "mark
  # ready" both hinge on this — we never post or ready a past day.
  def postable_today?
    post_date == social_region.local_today
  end

  def past?
    post_date < social_region.local_today
  end

  def any_selection?
    feed_alternative_id.present? || reel_alternative_id.present? || carousel_alternative_id.present?
  end

  # True when at least one selected slot actually carries an image or video. A
  # slot can be picked but point at a variant with no attached asset (all-text),
  # which posts nothing — readiness and publishing hinge on this, not just on a
  # slot being selected.
  def publishable_media?
    selected_slots.any? { |slot, alt| alt&.has_slot_media?(slot) }
  end

  # The selected slots as { "feed" => alt, "reel" => alt, "carousel" => alt }
  # (only picked ones).
  def selected_slots
    {}.tap do |slots|
      slots["feed"] = feed_alternative if feed_alternative_id.present?
      slots["reel"] = reel_alternative if reel_alternative_id.present?
      slots["carousel"] = carousel_alternative if carousel_alternative_id.present?
    end
  end

  private

  def must_have_media
    return if publishable_media?

    errors.add(:base, "needs a creative with an image or video before it can be readied")
  end
end
