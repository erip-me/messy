class DripEnrollment < ApplicationRecord
  belongs_to :drip_campaign
  belongs_to :account
  belongs_to :customer
  belongs_to :segment_membership, optional: true

  has_many :drip_step_executions, dependent: :destroy

  STATUSES = %w[active completed exited canceled].freeze

  validates :status, inclusion: { in: STATUSES }

  scope :active, -> { where(status: "active") }

  def active?
    status == "active"
  end
end
