class Click < ApplicationRecord
  belongs_to :account
  belongs_to :message

  validates :url, presence: true
  validates :clicked_at, presence: true

  scope :recent, -> { order(clicked_at: :desc) }
  scope :by_date, ->(date) { where(clicked_at: date.beginning_of_day..date.end_of_day) }

  def self.track_click(message, url, request)
    transaction do
      click_record = create!(
        account: message.account,
        message: message,
        url: url,
        clicked_at: Time.current,
        ip_address: request.remote_ip,
        user_agent: request.user_agent,
        referer: request.referer
      )

      # Update message stats
      if message.first_clicked_at.nil?
        message.update!(
          first_clicked_at: click_record.clicked_at,
          click_count: 1
        )
      else
        message.increment!(:click_count)
      end

      click_record
    end
  end
end
