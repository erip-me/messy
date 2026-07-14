require "test_helper"

class Socials::ProvisioningControllerTest < ActionDispatch::IntegrationTest
  setup do
    @env = environments(:production) # carries the api_key
    @region = social_regions(:pakistan)
  end

  test "rejects a missing or invalid api key" do
    post "/socials/provision",
         params: { region: "Pakistan", date: "2026-07-10", alternatives: [{ headline: "x" }] },
         as: :json
    assert_response :unauthorized
  end

  test "provisions a day with alternatives, identified by region name" do
    assert_difference -> { @region.social_posts.count }, 1 do
      post "/socials/provision",
           params: { region: "Pakistan", date: "2026-07-10", alternatives: [
             { headline: "H1", body: "B1", cta_label: "Sign Up", cta_url: "https://x" },
             { headline: "H2" }
           ] },
           headers: api_key_headers(@env), as: :json
    end

    assert_response :created
    json = JSON.parse(response.body)
    assert json["success"]
    assert_equal 2, json["data"]["alternative_ids"].length
  end

  test "downloads and attaches media from a url" do
    Socials::ProvisioningController.any_instance.stubs(:download).returns(["bytes", "image/png"])

    post "/socials/provision",
         params: { region: @region.id.to_s, date: "2026-07-11",
                   alternatives: [{ headline: "H", feed_media_url: "https://cdn/x.png" }] },
         headers: api_key_headers(@env), as: :json

    assert_response :created
    alt = @region.social_posts.find_by(post_date: Date.new(2026, 7, 11)).social_alternatives.first
    assert alt.feed_media.attached?
  end

  test "replace true removes prior generated variants but keeps manual uploads" do
    day = @region.social_posts.create!(post_date: Date.new(2026, 7, 12))
    day.social_alternatives.create!(source: :generated, position: 0, headline: "old")
    day.social_alternatives.create!(source: :manual, position: 1, headline: "keep")

    post "/socials/provision",
         params: { region: @region.id.to_s, date: "2026-07-12", replace: true,
                   alternatives: [{ headline: "new" }] },
         headers: api_key_headers(@env), as: :json

    assert_response :created
    headlines = day.reload.social_alternatives.pluck(:headline)
    assert_includes headlines, "new"
    assert_includes headlines, "keep"
    assert_not_includes headlines, "old"
  end

  test "unknown region is a 404" do
    post "/socials/provision",
         params: { region: "Atlantis", date: "2026-07-10", alternatives: [{ headline: "x" }] },
         headers: api_key_headers(@env), as: :json
    assert_response :not_found
  end
end
