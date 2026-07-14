# A market a content calendar is organised around. Account-scoped (optionally
# environment-scoped), carries the posting timezone + daily post hour + ad
# targeting countries, and the Meta publishing target: which credential (token)
# integration to use plus the Page / Instagram / ad account under it.
class SocialRegion < ApplicationRecord
  belongs_to :account
  belongs_to :environment, optional: true
  belongs_to :integration, optional: true # the Meta credential (token) to publish with
  belongs_to :linkedin_integration, class_name: "Integration", optional: true # the LinkedIn credential to publish with

  has_many :social_channels, dependent: :destroy # legacy link table, no longer used
  has_many :social_posts, dependent: :destroy

  validates :name, presence: true
  validates :post_hour, inclusion: { in: 0..23 }
  validate  :timezone_is_valid

  scope :active, -> { where(active: true) }

  # The Meta credential this region publishes with (nil until one is chosen).
  def token_integration
    integration if integration.is_a?(MetaSocialIntegration)
  end

  # The LinkedIn credential this region publishes with (nil until one is chosen).
  def linkedin_token_integration
    linkedin_integration if linkedin_integration.is_a?(LinkedinSocialIntegration)
  end

  # Ready to publish somewhere: a Meta target and/or a LinkedIn target is set up.
  def configured?
    meta_configured? || linkedin_configured?
  end

  # Meta is publishable: a configured credential + a selected Page.
  def meta_configured?
    token_integration&.configured? && page_id.present?
  end

  # LinkedIn is publishable: a connected credential + a selected organization.
  def linkedin_configured?
    linkedin_token_integration&.configured? && linkedin_org_id.present?
  end

  # The Page whose token publishes to the selected IG account. IG accounts can
  # be connected to a different Page than the one chosen for Facebook, so this
  # falls back to the Facebook Page for regions saved before ig_page_id existed.
  def ig_publish_page_id
    ig_page_id.presence || page_id
  end

  # Instagram is publishable: a connected credential, a chosen IG account, and a
  # Page whose token can publish to it. Independent of the Facebook Page choice.
  def instagram_available?
    token_integration&.configured? && ig_business_account_id.present? && ig_publish_page_id.present?
  end

  def linkedin_available?
    linkedin_configured?
  end

  # `hashtags` is a reference pool the generator picks from when writing a
  # creative's copy; nothing is appended automatically.

  # Channels a scheduled post targets by default, filtered to what's available
  # and switched on. Toggles default ON.
  def enabled_channels
    channels = []
    channels << "facebook" if meta_configured? && post_to_facebook?
    channels << "instagram" if instagram_available? && post_to_instagram?
    channels << "linkedin" if linkedin_configured? && post_to_linkedin?
    channels
  end

  # Channels this region could post to, ignoring the on/off toggles.
  def available_channels
    channels = []
    channels << "facebook" if meta_configured?
    channels << "instagram" if instagram_available?
    channels << "linkedin" if linkedin_configured?
    channels
  end

  def local_now
    Time.current.in_time_zone(timezone)
  end

  def local_today
    local_now.to_date
  end

  private

  def timezone_is_valid
    TZInfo::Timezone.get(timezone.to_s)
  rescue TZInfo::InvalidTimezoneIdentifier
    errors.add(:timezone, "is not a valid IANA timezone")
  end
end
