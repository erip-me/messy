class Segment < ApplicationRecord
  belongs_to :account
  has_many :segment_memberships, dependent: :destroy
  has_many :drip_campaigns, dependent: :destroy
  validates :name, presence: true

  def evaluate(account)
    SegmentEvaluator.new(account.customers, conditions).evaluate
  end
end
