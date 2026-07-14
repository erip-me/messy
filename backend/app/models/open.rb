class Open < ApplicationRecord
  belongs_to :account
  belongs_to :message

  validates :opened_at, presence: true
  validates :ip_address, presence: true

  scope :recent, -> { order(opened_at: :desc) }
  scope :by_date, ->(date) { where(opened_at: date.beginning_of_day..date.end_of_day) }
  
  def self.track_open(message, request)
    transaction do
      # Create the open record
      open_record = create!(
        account: message.account,
        message: message,
        opened_at: Time.current,
        ip_address: request.remote_ip,
        user_agent: request.user_agent,
        referer: request.referer
      )

      # Update message stats
      if message.first_opened_at.nil?
        message.update!(
          first_opened_at: open_record.opened_at,
          open_count: 1
        )
      else
        message.increment!(:open_count)
      end

      open_record
    end
  end
end