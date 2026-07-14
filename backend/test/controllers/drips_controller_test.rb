require "test_helper"

class DripsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:admin)
    @account = accounts(:acme)
    @headers = auth_headers(@user).merge("X-Environment-Id" => environments(:production).id.to_s)
    @segment = @account.segments.create!(name: "Sellers",
      conditions: { "operator" => "and", "conditions" => [{ "attribute" => "custom.is_seller", "operator" => "equals", "value" => "true" }] })
    # Email template that carries an unsubscribe link (required to activate).
    @compliant = @account.templates.create!(environment: environments(:production), name: "Compliant",
      trigger: "drip_compliant", channel: "email", subject: "Hi",
      body: 'Hi <a href="{{unsubscribe_url}}">unsubscribe</a>', body_format: "html")
  end

  # Counts real SELECT queries (ignores schema introspection and transactions).
  def count_select_queries
    count = 0
    counter = lambda do |_name, _start, _finish, _id, payload|
      sql = payload[:sql]
      next if payload[:name] == "SCHEMA"
      next unless sql =~ /\ASELECT/i
      count += 1
    end
    ActiveSupport::Notifications.subscribed(counter, "sql.active_record") { yield }
    count
  end

  test "index does not run per-drip queries (no N+1)" do
    create_drip = lambda do |n|
      drip = @account.drip_campaigns.create!(name: "D#{n}", segment: @segment, environment: environments(:production))
      drip.drip_steps.create!(account: @account, position: 0, template: @compliant, delay_days: 0)
      drip
    end

    create_drip.call(1)
    one_drip_queries = count_select_queries do
      get drips_path, headers: @headers
      assert_response :success
    end

    create_drip.call(2)
    create_drip.call(3)
    create_drip.call(4)
    four_drip_queries = count_select_queries do
      get drips_path, headers: @headers
      assert_response :success
      assert_equal 4, JSON.parse(response.body).length
    end

    assert_equal one_drip_queries, four_drip_queries,
      "index query count must not grow with the number of drips (N+1)"
  end

  test "create a drip with steps" do
    assert_difference -> { DripCampaign.count }, 1 do
      post drips_path, params: {
        name: "Seller onboarding",
        segment_id: @segment.id,
        exit_on_segment_leave: true,
        steps: [
          { position: 0, template_id: templates(:welcome).id, delay_days: 0 },
          { position: 1, template_id: templates(:welcome).id, delay_days: 3,
            conditions: { operator: "and", conditions: [{ attribute: "custom.product_uploaded", operator: "is_blank" }] },
            on_fail: "skip" }
        ]
      }, headers: @headers
    end

    assert_response :created
    body = JSON.parse(response.body)
    assert_equal "draft", body["status"]
    assert_equal 2, body["steps"].length
    assert_equal "is_blank", body["steps"][1]["conditions"]["conditions"][0]["operator"]
    assert_equal "Welcome Email", body["steps"][0]["template"]["name"]
  end

  test "update replaces steps by position" do
    drip = @account.drip_campaigns.create!(name: "D", segment: @segment, environment: environments(:production))
    drip.drip_steps.create!(account: @account, position: 0, template: templates(:welcome), delay_days: 0)

    patch drip_path(drip), params: {
      steps: [
        { position: 0, template_id: templates(:welcome).id, delay_days: 0 },
        { position: 1, template_id: templates(:welcome).id, delay_days: 5 }
      ]
    }, headers: @headers

    assert_response :success
    assert_equal 2, drip.reload.drip_steps.count
    assert_equal 5, drip.drip_steps.find_by(position: 1).delay_days
  end

  test "activate requires at least one step" do
    drip = @account.drip_campaigns.create!(name: "Empty", segment: @segment, environment: environments(:production))
    post activate_drip_path(drip), headers: @headers
    assert_response :unprocessable_entity

    drip.drip_steps.create!(account: @account, position: 0, template: @compliant, delay_days: 0)
    post activate_drip_path(drip), headers: @headers
    assert_response :success
    assert_equal "active", drip.reload.status
  end

  test "activate is blocked when an email step has no unsubscribe link" do
    drip = @account.drip_campaigns.create!(name: "NoUnsub", segment: @segment, environment: environments(:production))
    drip.drip_steps.create!(account: @account, position: 0, template: templates(:welcome), delay_days: 0) # welcome has no {{unsubscribe_url}}

    post activate_drip_path(drip), headers: @headers
    assert_response :unprocessable_entity
    assert_match(/unsubscribe_url/, JSON.parse(response.body)["error"])
    assert_equal "draft", drip.reload.status
  end

  test "activate succeeds when the unsubscribe link is in the layout not the body" do
    layout = Layout.create!(account: @account, environment: environments(:production), name: "Footer With Unsub",
      body: '<html><body>{{ content }}<a href="{{ unsubscribe_url }}">unsubscribe</a></body></html>', transformers: {})
    template = @account.templates.create!(environment: environments(:production), name: "Body Without Unsub",
      trigger: "drip_layout_unsub", channel: "email", subject: "Hi",
      body: "<p>No unsubscribe in the body.</p>", body_format: "html", layout: layout)
    drip = @account.drip_campaigns.create!(name: "LayoutUnsub", segment: @segment, environment: environments(:production))
    drip.drip_steps.create!(account: @account, position: 0, template: template, delay_days: 0)

    post activate_drip_path(drip), headers: @headers
    assert_response :success
    assert_equal "active", drip.reload.status
  end

  test "activate enrolls existing segment members when enroll_existing_on_start is true" do
    drip = @account.drip_campaigns.create!(name: "D", segment: @segment, environment: environments(:production), enroll_existing_on_start: true)
    drip.drip_steps.create!(account: @account, position: 0, template: @compliant, delay_days: 0)

    DripBackfillJob.expects(:perform_later).with(drip.id).once
    post activate_drip_path(drip), headers: @headers
    assert_response :success
  end

  test "activate does not backfill when enroll_existing_on_start is false" do
    drip = @account.drip_campaigns.create!(name: "D", segment: @segment, environment: environments(:production), enroll_existing_on_start: false)
    drip.drip_steps.create!(account: @account, position: 0, template: @compliant, delay_days: 0)

    DripBackfillJob.expects(:perform_later).never
    post activate_drip_path(drip), headers: @headers
    assert_response :success
    assert_equal "active", drip.reload.status
  end

  test "pause sets status to paused" do
    drip = @account.drip_campaigns.create!(name: "D", segment: @segment, environment: environments(:production), status: "active")
    post pause_drip_path(drip), headers: @headers
    assert_response :success
    assert_equal "paused", drip.reload.status
  end

  test "index is scoped to the current account" do
    @account.drip_campaigns.create!(name: "Mine", segment: @segment, environment: environments(:production))
    other = accounts(:other_co)
    other_seg = other.segments.create!(name: "x", conditions: { "operator" => "and", "conditions" => [] })
    other.drip_campaigns.create!(name: "Theirs", segment: other_seg)

    get drips_path, headers: @headers
    assert_response :success
    names = JSON.parse(response.body).map { |d| d["name"] }
    assert_includes names, "Mine"
    assert_not_includes names, "Theirs"
  end

  test "cannot access another account's drip" do
    other = accounts(:other_co)
    other_seg = other.segments.create!(name: "x", conditions: { "operator" => "and", "conditions" => [] })
    drip = other.drip_campaigns.create!(name: "Theirs", segment: other_seg)

    get drip_path(drip), headers: @headers
    assert_response :not_found
  end

  test "requires authentication" do
    get drips_path
    assert_response :unauthorized
  end

  test "manages drips with an environment API key" do
    key_headers = api_key_headers(environments(:production))

    # create
    assert_difference -> { DripCampaign.count }, 1 do
      post drips_path, params: {
        name: "API onboarding", segment_id: @segment.id,
        steps: [{ position: 0, template_id: @compliant.id, delay_days: 0 }]
      }, headers: key_headers
    end
    assert_response :created
    drip_id = JSON.parse(response.body)["id"]
    assert_equal @account.id, DripCampaign.find(drip_id).account_id
    assert_equal environments(:production).id, DripCampaign.find(drip_id).environment_id

    # index
    get drips_path, headers: key_headers
    assert_response :success
    assert_includes JSON.parse(response.body).map { |d| d["name"] }, "API onboarding"

    # activate
    post activate_drip_path(drip_id), headers: key_headers
    assert_response :success
    assert_equal "active", DripCampaign.find(drip_id).status

    # pause
    post pause_drip_path(drip_id), headers: key_headers
    assert_response :success
    assert_equal "paused", DripCampaign.find(drip_id).status

    # delete
    delete drip_path(drip_id), headers: key_headers
    assert_response :success
    assert_nil DripCampaign.find_by(id: drip_id)
  end
end
