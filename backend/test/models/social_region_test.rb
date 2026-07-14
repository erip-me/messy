require "test_helper"

class SocialRegionTest < ActiveSupport::TestCase
  setup { @region = social_regions(:pakistan) } # Meta-configured (token + page + ig)

  def link_linkedin!
    @region.update!(linkedin_integration: integrations(:linkedin_social), linkedin_org_id: "999001")
  end

  test "meta_configured? and linkedin_configured? are independent" do
    assert @region.meta_configured?
    assert_not @region.linkedin_configured?

    link_linkedin!
    assert @region.linkedin_configured?
    assert @region.linkedin_available?
  end

  test "enabled_channels adds linkedin only when configured and toggled on" do
    link_linkedin!
    assert_includes @region.enabled_channels, "linkedin"

    @region.update!(post_to_linkedin: false)
    assert_not_includes @region.enabled_channels, "linkedin"
    assert_includes @region.available_channels, "linkedin" # available ignores the toggle
  end

  test "configured? is true with only a linkedin target" do
    region = accounts(:acme).social_regions.create!(
      name: "LinkedIn only", timezone: "UTC", post_hour: 9,
      linkedin_integration: integrations(:linkedin_social), linkedin_org_id: "999001"
    )
    assert region.configured?
    assert_not region.meta_configured?
    assert_equal %w[linkedin], region.available_channels
  end

  test "instagram_available? requires a configured meta target, not just an ig id" do
    region = accounts(:acme).social_regions.create!(
      name: "No meta", timezone: "UTC", post_hour: 9, ig_business_account_id: "170000000000009"
    )
    assert_not region.instagram_available?
  end
end
