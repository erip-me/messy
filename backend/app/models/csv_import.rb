class CsvImport < ApplicationRecord
  belongs_to :account
  belongs_to :user

  STATUSES = %w[pending processing completed failed].freeze
  DEDUP_STRATEGIES = %w[skip update].freeze

  validates :status, inclusion: { in: STATUSES }
  validates :dedup_strategy, inclusion: { in: DEDUP_STRATEGIES }
end
