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
end
