class DripStepExecution < ApplicationRecord
  belongs_to :drip_enrollment
  belongs_to :drip_step
  belongs_to :account
  belongs_to :message, optional: true

  STATUSES = %w[sent skipped suppressed failed].freeze

  validates :status, inclusion: { in: STATUSES }
end
