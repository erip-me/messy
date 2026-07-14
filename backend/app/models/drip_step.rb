class DripStep < ApplicationRecord
  belongs_to :drip_campaign
  belongs_to :account
  belongs_to :template, optional: true

  ON_FAIL = %w[skip exit].freeze

  validates :position, presence: true
  validates :delay_days, numericality: { greater_than_or_equal_to: 0 }
  validates :on_fail, inclusion: { in: ON_FAIL }

  # A step with no conditions always sends; otherwise reuse the Segment DSL.
  def conditional?
    conditions.present? && Array(conditions["conditions"]).any?
  end
end
