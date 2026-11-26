require "test_helper"

class SentryScrubTest < ActiveSupport::TestCase
  test "filters token path segments and query values" do
    token = "a" * 64
    assert_equal "https://api.messy.sh/track/[filtered].png", SentryScrub.url("https://api.messy.sh/track/#{token}.png")
    assert_equal "https://api.messy.sh/campaign_track/[filtered]/click?[filtered]",
                 SentryScrub.url("https://api.messy.sh/campaign_track/#{token}/click?url=https://x.test")
    assert_equal "https://api.messy.sh/messages/42", SentryScrub.url("https://api.messy.sh/messages/42")
  end
end
