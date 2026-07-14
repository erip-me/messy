class PageVisit < ApplicationRecord
  belongs_to :account
  belongs_to :customer, optional: true

  validates :visitor_token, :url, :visited_at, presence: true

  scope :recent, -> { order(visited_at: :desc) }

  def self.record_visit!(account_id:, visitor_token:, url:, title: nil, customer_id: nil)
    # Skip if the most recent visit is the same URL
    last_url = where(account_id: account_id, visitor_token: visitor_token)
                 .order(visited_at: :desc).limit(1).pick(:url)
    return if last_url == url

    create!(
      account_id: account_id,
      visitor_token: visitor_token,
      customer_id: customer_id,
      url: url,
      title: title,
      visited_at: Time.current
    )

    trim!(account_id, visitor_token)
  end

  def self.trim!(account_id, visitor_token)
    ids = where(account_id: account_id, visitor_token: visitor_token)
            .order(visited_at: :desc).offset(50).pluck(:id)
    where(id: ids).delete_all if ids.any?
  end
end
