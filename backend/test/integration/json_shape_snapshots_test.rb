require "test_helper"

# Characterization tests for the JSON layer, written ahead of the Alba
# migration. Each snapshot records the response's key paths and value types
# into a golden file under test/json_shapes/. On the first run a missing
# golden is recorded from the current implementation; afterwards any shape
# drift fails the test. Delete a golden file to deliberately re-record it.
class JsonShapeSnapshotsTest < ActionDispatch::IntegrationTest
  SNAPSHOT_DIR = Rails.root.join("test/json_shapes")

  setup do
    @admin = users(:admin) # also a super admin in fixtures
    @headers = auth_headers(@admin).merge("X-Environment-Id" => environments(:production).id.to_s)
  end

  test "users endpoints" do
    snap "users.index", "/users"
    snap "users.show", "/users/#{users(:regular).id}"
    snap "users.me", "/users/me"
  end

  test "accounts and environments endpoints" do
    snap "accounts.index", "/accounts"
    snap "accounts.show", "/accounts/#{accounts(:acme).id}"
    snap "environments.index", "/environments"
    snap "environments.show", "/environments/#{environments(:production).id}"
  end

  test "integrations endpoints" do
    snap "integrations.index", "/integrations"
    snap "integrations.show", "/integrations/#{integrations(:ses).id}"
  end

  test "messages endpoints" do
    snap "messages.index", "/messages"
    snap "messages.show", "/messages/#{messages(:email_one).id}"
  end

  test "templates layouts folders rules endpoints" do
    snap "templates.index", "/templates"
    snap "templates.show", "/templates/#{templates(:welcome).id}"
    snap "layouts.index", "/layouts"
    snap "layouts.show", "/layouts/#{layouts(:default_layout).id}"
    snap "folders.index", "/folders"
    snap "folders.show", "/folders/#{folders(:root_folder).id}"
    snap "rules.index", "/rules"
    snap "rules.show", "/rules/#{rules(:allow_internal).id}"
  end

  test "customers and segments endpoints" do
    snap "customers.index", "/customers"
    snap "customers.show", "/customers/#{customers(:john).id}"
    snap "customers.recent_activities", "/customers/recent_activities"
    snap "segments.index", "/segments"
    snap "segments.show", "/segments/#{segments(:active_buyers).id}"
    snap "segments.attributes", "/segments/attributes"
    snap "csv_imports.index", "/csv_imports"
  end

  test "device tokens and sending identities endpoints" do
    snap "device_tokens.index", "/device_tokens?email=john@example.com"
    snap "sending_identities.index", "/sending_identities"
  end

  test "dashboard and helpdesk stats endpoints" do
    snap "dashboard.stats", "/dashboard/stats"
    snap "helpdesk.stats", "/helpdesk/stats"
    snap "chat_settings.show", "/chat_settings"
  end

  test "campaigns endpoints" do
    snap "campaigns.index", "/campaigns"
    snap "campaigns.show", "/campaigns/#{campaigns(:email_draft).id}"
    snap "campaigns.deliveries", "/campaigns/#{campaigns(:sending_campaign).id}/deliveries"
  end

  test "drips endpoints" do
    account = accounts(:acme)
    segment = account.segments.create!(name: "Snapshot segment",
      conditions: { "operator" => "and", "conditions" => [{ "attribute" => "custom.is_seller", "operator" => "equals", "value" => "true" }] })
    template = account.templates.create!(environment: environments(:production), name: "Snapshot drip template",
      trigger: "drip_snapshot", channel: "email", subject: "Hi",
      body: 'Hi <a href="{{unsubscribe_url}}">unsubscribe</a>', body_format: "html")
    drip = account.drip_campaigns.create!(name: "Snapshot drip", segment: segment, environment: environments(:production))
    drip.drip_steps.create!(account: account, position: 0, template: template, delay_days: 1)

    snap "drips.index", "/drips"
    snap "drips.show", "/drips/#{drip.id}"
  end

  test "conversations endpoints" do
    snap "conversations.index", "/conversations"
    snap "conversations.show", "/conversations/#{conversations(:open_chat).id}"
    snap "conversations.messages", "/conversations/#{conversations(:open_chat).id}/messages"
    snap "conversations.stats", "/conversations/stats"
    snap "conversation_tags.index", "/conversation_tags"
    snap "canned_responses.index", "/canned_responses"
  end

  test "mailboxes and operator profiles endpoints" do
    snap "mailboxes.index", "/mailboxes"
    snap "mailboxes.show", "/mailboxes/#{mailboxes(:support).id}"
    snap "operator_profiles.index", "/operator_profiles"
    snap "operator_profile.show", "/operator_profile"
  end

  test "socials endpoints" do
    region = social_regions(:pakistan)
    post_record = region.social_posts.create!(post_date: region.local_today)
    alt = post_record.social_alternatives.create!(source: :generated, position: 0, headline: "H")
    alt.feed_media.attach(io: StringIO.new("img"), filename: "f.png", content_type: "image/png")

    snap "social_regions.index", "/social_regions"
    snap "social_regions.show", "/social_regions/#{region.id}"
    snap "social_regions.calendar", "/social_regions/#{region.id}/calendar?month=#{region.local_today.strftime('%Y-%m')}"
    snap "social_posts.show", "/social_posts/#{post_record.id}"
  end

  test "super admin endpoints" do
    snap "super_admin.users.index", "/admin/users"
    snap "super_admin.users.show", "/admin/users/#{users(:regular).id}"
    snap "super_admin.accounts.index", "/admin/accounts"
    snap "super_admin.accounts.show", "/admin/accounts/#{accounts(:acme).id}"
  end

  private

  def snap(name, path)
    get path, headers: @headers, as: :json
    assert_response :success, "GET #{path} failed: #{response.status} #{response.body.truncate(200)}"
    record_or_assert(name, JSON.parse(response.body))
  end

  def record_or_assert(name, json)
    actual = shape_of(json).join("\n") + "\n"
    golden = SNAPSHOT_DIR.join("#{name}.txt")
    if golden.exist?
      assert_equal golden.read, actual,
        "JSON shape drifted for #{name} — if intentional, delete #{golden.relative_path_from(Rails.root)} and re-run to re-record"
    else
      FileUtils.mkdir_p(SNAPSHOT_DIR)
      golden.write(actual)
    end
  end

  # Sorted key paths with value types; arrays fold every element's shape (uniq),
  # so heterogeneous lists and nullable fields are captured deterministically.
  def shape_of(node, prefix = "$")
    case node
    when Hash
      node.empty? ? ["#{prefix}: {}"] : node.keys.sort.flat_map { |k| shape_of(node[k], "#{prefix}.#{k}") }
    when Array
      node.empty? ? ["#{prefix}[]: (empty)"] : node.flat_map { |el| shape_of(el, "#{prefix}[]") }.uniq.sort
    else
      ["#{prefix}: #{scalar_type(node)}"]
    end
  end

  def scalar_type(value)
    case value
    when true, false then "Boolean"
    when nil then "Null"
    when Integer then "Integer"
    when Float then "Float"
    else "String"
    end
  end
end
