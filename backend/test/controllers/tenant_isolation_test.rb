require "test_helper"

# =============================================================================
# Controller-Level Tenant Isolation Tests
#
# These tests verify that HTTP API endpoints enforce strict multi-tenant
# data isolation. Each test attempts a cross-tenant operation and asserts
# it is blocked.
# =============================================================================

class MassAssignmentIsolationTest < ActionDispatch::IntegrationTest
  # -------------------------------------------------------------------------
  # account_id must never be settable through strong params
  # -------------------------------------------------------------------------

  test "cannot reassign integration to another account via mass assignment" do
    user = users(:admin)
    integration = integrations(:ses)
    other = accounts(:other_co)

    patch "/integrations/#{integration.id}",
      params: { integration: { account_id: other.id } },
      headers: auth_headers(user),
      as: :json

    integration.reload
    assert_equal accounts(:acme).id, integration.account_id,
      "Integration account_id must not change via mass assignment"
  end

  test "cannot reassign user to another account via mass assignment" do
    user = users(:regular)
    other = accounts(:other_co)

    patch "/users/#{user.id}",
      params: { user: { account_id: other.id, name: "Same Name" } },
      headers: auth_headers(users(:admin)),
      as: :json

    user.reload
    assert_equal accounts(:acme).id, user.account_id,
      "User account_id must not change via mass assignment"
  end

  test "cannot reassign environment to another account via mass assignment" do
    user = users(:admin)
    env = environments(:production)
    other = accounts(:other_co)

    patch "/environments/#{env.id}",
      params: { environment: { account_id: other.id } },
      headers: auth_headers(user),
      as: :json

    env.reload
    assert_equal accounts(:acme).id, env.account_id,
      "Environment account_id must not change via mass assignment"
  end
end

class LayoutIsolationTest < ActionDispatch::IntegrationTest
  test "cannot read another account's layout" do
    other_layout = layouts(:other_layout) # other_co

    get "/layouts/#{other_layout.id}",
      headers: api_key_headers(environments(:production)),
      as: :json

    assert_response :not_found
  end

  test "cannot update another account's layout" do
    other_layout = layouts(:other_layout)

    patch "/layouts/#{other_layout.id}",
      params: { layout: { name: "Hacked" } },
      headers: api_key_headers(environments(:production)),
      as: :json

    assert_response :not_found
    other_layout.reload
    assert_equal "Other Layout", other_layout.name
  end

  test "cannot delete another account's layout" do
    other_layout = layouts(:other_layout)

    delete "/layouts/#{other_layout.id}",
      headers: api_key_headers(environments(:production)),
      as: :json

    assert_response :not_found
    assert Layout.exists?(other_layout.id)
  end

  test "can read own account layout" do
    get "/layouts/#{layouts(:default_layout).id}",
      headers: api_key_headers(environments(:production)),
      as: :json

    assert_response :success
  end
end

class DeviceTokenIsolationTest < ActionDispatch::IntegrationTest
  test "device token cleanup only removes tokens within same account" do
    acme_customer_john = customers(:john)
    acme_customer_jane = customers(:jane)

    token_value = "device_isolation_test_#{SecureRandom.hex(8)}"

    # John registers a device token in acme account
    johns_dt = DeviceToken.create!(
      account: accounts(:acme),
      customer: acme_customer_john,
      token: token_value,
      platform: "ios",
      active: true
    )

    # Jane in the same account registers the same token (device switched users).
    # The cleanup should remove John's token within acme.
    post "/device_tokens",
      params: { token: token_value, email: "jane@example.com", platform: "ios" },
      headers: api_key_headers(environments(:production)),
      as: :json

    assert_response :created

    # John's token within acme should be cleaned up
    assert_not DeviceToken.exists?(johns_dt.id),
      "Same-account token for different customer should be cleaned up"
  end

  test "device token deletion via destroy is scoped to account" do
    # Verify that DELETE /device_tokens/:id only finds tokens within the requesting account
    other_customer = customers(:other_customer)
    other_token = DeviceToken.create!(
      account: accounts(:other_co),
      customer: other_customer,
      token: "other_co_only_token_#{SecureRandom.hex(8)}",
      platform: "android",
      active: true
    )

    # Try to delete other_co's token via acme's API key
    delete "/device_tokens/#{other_token.id}",
      headers: api_key_headers(environments(:production)),
      as: :json

    assert_response :not_found
    assert DeviceToken.exists?(other_token.id),
      "Cross-account device token must not be deleted via API"
  end
end

class ConversationIsolationTest < ActionDispatch::IntegrationTest
  test "cannot view conversations from another account" do
    other_conv = conversations(:other_account_chat)

    get "/conversations/#{other_conv.id}",
      headers: auth_headers(users(:admin)),
      as: :json

    assert_response :not_found
  end

  test "cannot create messages in another account's conversation" do
    other_conv = conversations(:other_account_chat)

    post "/conversations/#{other_conv.id}/create_message",
      params: { content: "Injected message" },
      headers: auth_headers(users(:admin)),
      as: :json

    assert_response :not_found
  end

  test "cannot assign operator to another account's conversation" do
    other_conv = conversations(:other_account_chat)

    post "/conversations/#{other_conv.id}/assign",
      params: { user_id: users(:admin).id },
      headers: auth_headers(users(:admin)),
      as: :json

    assert_response :not_found
  end

  test "conversation index only returns own account conversations" do
    get "/conversations",
      headers: auth_headers(users(:admin)),
      as: :json

    assert_response :success
    json = JSON.parse(response.body)
    account_ids = json["conversations"].map { |c|
      Conversation.find(c["id"]).account_id
    }.uniq

    assert_equal [accounts(:acme).id], account_ids
  end
end

class WidgetConversationIsolationTest < ActionDispatch::IntegrationTest
  setup do
    @acme = accounts(:acme)
    @acme_widget = chat_widget_settings(:acme_settings)
    @visitor_token = "test_visitor_isolation_#{SecureRandom.hex(8)}"
  end

  test "widget visitor can only see own conversations" do
    conv = Conversation.create!(
      account: @acme,
      environment: environments(:production),
      visitor_token: @visitor_token,
      visitor_name: "Test Visitor",
      status: :open,
      source: :widget
    )

    get "/widget/v1/conversations",
      headers: {
        "X-Widget-Key" => @acme_widget.widget_key,
        "X-Visitor-Token" => @visitor_token
      },
      as: :json

    assert_response :success
    json = JSON.parse(response.body)
    returned_ids = json["conversations"].map { |c| c["id"] }
    assert_includes returned_ids, conv.id

    other_conv = conversations(:other_account_chat)
    assert_not_includes returned_ids, other_conv.id
  end

  test "widget visitor cannot access conversation from different account" do
    other_conv = conversations(:other_account_chat)

    post "/widget/v1/conversations/#{other_conv.id}/messages",
      params: { content: "injected" },
      headers: {
        "X-Widget-Key" => @acme_widget.widget_key,
        "X-Visitor-Token" => @visitor_token
      },
      as: :json

    assert_response :not_found
  end

  test "widget visitor cannot access conversation with mismatched visitor_token" do
    conv = conversations(:open_chat) # visitor_token is "visitor_token_abc123"

    get "/widget/v1/conversations/#{conv.id}/messages",
      headers: {
        "X-Widget-Key" => @acme_widget.widget_key,
        "X-Visitor-Token" => "wrong_visitor_token"
      },
      as: :json

    assert_response :not_found
  end

  test "widget with other_co key cannot see acme conversations" do
    # Enable chat on other_co for this test
    accounts(:other_co).update_column(:chat_enabled, true)

    other_widget = chat_widget_settings(:other_settings)
    acme_conv = conversations(:open_chat)

    get "/widget/v1/conversations/#{acme_conv.id}/messages",
      headers: {
        "X-Widget-Key" => other_widget.widget_key,
        "X-Visitor-Token" => acme_conv.visitor_token
      },
      as: :json

    assert_response :not_found
  end
end

class WidgetAuthenticationIsolationTest < ActionDispatch::IntegrationTest
  test "rejects widget request with bare account_id instead of widget_key" do
    get "/widget/v1/config",
      headers: { "X-Account-Id" => accounts(:acme).id.to_s },
      as: :json

    assert_response :unauthorized
  end

  test "rejects widget request with account_id param instead of widget_key" do
    post "/widget/v1/conversations",
      params: { initial_message: "Hello!", account_id: accounts(:acme).id },
      headers: { "X-Visitor-Token" => "attacker_token" },
      as: :json

    assert_response :unauthorized
  end

  test "rejects widget conversation create with bare account_id" do
    post "/widget/v1/conversations",
      params: { initial_message: "Hello!", account_id: accounts(:acme).id },
      headers: { "X-Visitor-Token" => "attacker_token" },
      as: :json

    assert_response :unauthorized
  end

  test "accepts widget request with valid widget_key" do
    get "/widget/v1/config",
      headers: { "X-Widget-Key" => chat_widget_settings(:acme_settings).widget_key },
      as: :json

    assert_response :success
  end

  test "rejects widget request with invalid widget_key" do
    get "/widget/v1/config",
      headers: { "X-Widget-Key" => "totally_bogus_key" },
      as: :json

    assert_response :not_found
  end

  test "cannot create conversation in other account by spoofing account_id with valid widget_key" do
    # Attacker uses acme's widget key but passes other_co's account_id in params
    # The widget_key should determine the account, not any param
    acme_widget = chat_widget_settings(:acme_settings)
    other = accounts(:other_co)

    post "/widget/v1/conversations",
      params: { initial_message: "Hello!", account_id: other.id },
      headers: {
        "X-Widget-Key" => acme_widget.widget_key,
        "X-Visitor-Token" => "attacker_token"
      },
      as: :json

    assert_response :created
    json = JSON.parse(response.body)
    conv = Conversation.find(json["conversation"]["id"])
    # Conversation must belong to acme (from widget_key), not other_co
    assert_equal accounts(:acme).id, conv.account_id
  end
end

class IntegrationIsolationTest < ActionDispatch::IntegrationTest
  test "cannot view another account's integrations" do
    get "/integrations",
      headers: auth_headers(users(:other_user)),
      as: :json

    assert_response :success
    json = JSON.parse(response.body)

    acme_integration_ids = accounts(:acme).integrations.pluck(:id)
    returned_ids = json.map { |i| i["id"] }

    acme_integration_ids.each do |acme_id|
      assert_not_includes returned_ids, acme_id,
        "Other account should not see acme's integrations"
    end
  end
end

class CustomerIsolationTest < ActionDispatch::IntegrationTest
  test "cannot view another account's customers" do
    get "/customers",
      headers: auth_headers(users(:admin)),
      as: :json

    assert_response :success
    json = JSON.parse(response.body)
    customer_ids = json["customers"].map { |c| c["id"] }

    assert_not_includes customer_ids, customers(:other_customer).id,
      "Should not return customers from other accounts"
  end
end

class PageVisitIsolationTest < ActionDispatch::IntegrationTest
  test "page visits in conversation detail are scoped to account" do
    customer = customers(:john)
    acme = accounts(:acme)
    conversation = conversations(:open_chat)

    PageVisit.create!(
      account: acme,
      customer: customer,
      visitor_token: conversation.visitor_token,
      url: "https://acme.com/pricing",
      title: "Pricing",
      visited_at: 1.minute.ago
    )

    get "/conversations/#{conversation.id}",
      headers: auth_headers(users(:admin)),
      as: :json

    assert_response :success
    json = JSON.parse(response.body)
    pages = json["customer"]["recent_pages"]
    assert pages.any? { |p| p["url"] == "https://acme.com/pricing" }
  end
end
