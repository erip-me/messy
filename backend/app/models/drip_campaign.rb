class DripCampaign < ApplicationRecord
  belongs_to :account
  belongs_to :environment, optional: true
  belongs_to :segment
  belongs_to :sending_identity, optional: true

  has_many :drip_steps, -> { order(:position) }, dependent: :destroy
  has_many :drip_enrollments, dependent: :destroy

  STATUSES = %w[draft active paused archived].freeze

  validates :name, presence: true
  validates :status, inclusion: { in: STATUSES }

  def ordered_steps
    # sort_by (not .order) so a preloaded drip_steps association is reused instead
    # of re-querying per drip in list endpoints. (position is unique per campaign.)
    drip_steps.sort_by(&:position)
  end

  def active?
    status == "active"
  end

  # When a step should fire. With anchor_attribute set, that is the customer's
  # date attribute + delay_days (negative = before it), so the schedule follows
  # the date even when it differs per customer. Nil when the attribute is
  # missing or unparseable. Otherwise delay_days after the last sent step.
  def step_run_at(step, enrollment)
    return (enrollment.anchor_at || Time.current) + step.delay_days.days if anchor_attribute.blank?

    time = Time.zone.parse(enrollment.customer.custom_attributes.to_h[anchor_attribute].to_s)
    time && time + step.delay_days.days
  rescue ArgumentError
    nil
  end
end
