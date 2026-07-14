# Links a region to one Meta social account. A region publishes its ready content
# to every channel linked here.
class SocialChannel < ApplicationRecord
  belongs_to :social_region
  belongs_to :integration

  validates :integration_id, uniqueness: { scope: :social_region_id }
  validate :integration_is_social

  private

  def integration_is_social
    errors.add(:integration, "must be a Meta social account") unless integration.is_a?(MetaSocialIntegration)
  end
end
