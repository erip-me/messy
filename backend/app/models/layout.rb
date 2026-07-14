class Layout < ApplicationRecord
  belongs_to :account
  belongs_to :environment

  has_many :templates, dependent: :nullify

  validates :name, presence: true, uniqueness: { scope: :environment_id, conditions: -> { where(is_deleted: false) } }
  validates :body, presence: true
  validate :body_contains_content_placeholder

  private

  def body_contains_content_placeholder
    return if body.blank?

    unless body.include?("{{ content }}") || body.include?("{{content}}")
      errors.add(:body, "must contain a {{ content }} placeholder")
    end
  end
end
