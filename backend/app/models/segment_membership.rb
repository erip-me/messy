class SegmentMembership < ApplicationRecord
  belongs_to :account
  belongs_to :segment
  belongs_to :customer

  scope :active, -> { where(exited_at: nil) }

  def active?
    exited_at.nil?
  end
end
