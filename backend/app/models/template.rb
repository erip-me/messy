class Template < ApplicationRecord
  belongs_to :account
  belongs_to :environment
  belongs_to :folder, optional: true
  belongs_to :layout, optional: true

  # validate message also be send custom message like if trigger error then send trigger is also present
  CHANNELS = %w[email sms whatsapp push].freeze
  BODY_FORMATS = %w[html markdown].freeze

  validates :trigger, presence: true, uniqueness: { scope: [:environment_id, :channel], conditions: -> { where(is_deleted: false) } }
  validates :name, presence: true
  validates :body, presence: true
  validates :channel, presence: true, inclusion: { in: CHANNELS }
  validates :body_format, presence: true, inclusion: { in: BODY_FORMATS }
end
