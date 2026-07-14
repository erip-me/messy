require "test_helper"

# End-to-end coverage of the MCP server: OAuth 2.1 discovery → DCR → PKCE
# authorize/consent → token → JSON-RPC tools, plus scope/admin filtering, the
# three gating tiers, and refresh-token rotation.
class McpFlowTest < ActionDispatch::IntegrationTest
  setup do
    @account = accounts(:acme)
    @admin = users(:admin)
    @member = users(:regular)
    @environment = environments(:production)
    # Master switch on for most tests.
    McpSetting.create!(account: @account, enabled: true)

    @verifier = SecureRandom.urlsafe_base64(32)
    @challenge = Base64.urlsafe_encode64(Digest::SHA256.digest(@verifier), padding: false)
    @redirect_uri = "https://client.example.com/callback"
  end

  # ── discovery ───────────────────────────────────────────────────────────────
  test "advertises authorization server + protected resource metadata" do
    get "/.well-known/oauth-authorization-server"
    assert_response :success
    meta = JSON.parse(response.body)
    assert_equal ["S256"], meta["code_challenge_methods_supported"]
    assert_includes meta["grant_types_supported"], "authorization_code"
    assert meta["authorization_endpoint"].end_with?("/oauth/authorize")

    get "/.well-known/oauth-protected-resource"
    assert_response :success
    assert JSON.parse(response.body)["resource"].end_with?("/mcp")
  end

  # ── unauthorized handshake ──────────────────────────────────────────────────
  test "mcp endpoint 401s with WWW-Authenticate pointing at discovery" do
    post "/mcp", params: { jsonrpc: "2.0", id: 1, method: "tools/list" }, as: :json
    assert_response :unauthorized
    assert_match %r{resource_metadata=".*/\.well-known/oauth-protected-resource"}, response.headers["WWW-Authenticate"]
  end

  # ── full happy path ─────────────────────────────────────────────────────────
  test "full oauth flow then tools/list and tools/call" do
    access, _refresh = connect_agent(user: @admin)

    # initialize
    rpc = mcp_call(access, "initialize", { protocolVersion: "2025-06-18" }, id: 1)
    assert_equal "Messy", rpc.dig("result", "serverInfo", "name")

    # tools/list — admin sees admin tools
    rpc = mcp_call(access, "tools/list", {}, id: 2)
    names = rpc.dig("result", "tools").map { |t| t["name"] }
    assert_includes names, "send_message"
    assert_includes names, "list_users" # admin-only

    # tools/call — dispatches to the real dashboard#stats endpoint
    rpc = mcp_call(access, "tools/call", { name: "dashboard_stats", arguments: {} }, id: 3)
    refute rpc.dig("result", "isError"), "dashboard_stats should succeed: #{rpc.inspect}"
    assert rpc.dig("result", "content", 0, "text").present?

    # a log row was written
    log = @account.mcp_request_logs.order(:created_at).last
    assert_equal "dashboard_stats", log.tool_name
    assert_equal "ok", log.status
  end

  test "a failing tool returns a legible isError result, not a broken envelope" do
    access, _ = connect_agent(user: @admin)
    rpc = mcp_call(access, "tools/call",
                   { name: "list_messages", arguments: { date_from: "not-a-date" } }, id: 1)

    # Still a well-formed JSON-RPC result (envelope intact), just flagged isError.
    assert_equal "2.0", rpc["jsonrpc"]
    assert rpc.dig("result", "isError"), "expected isError to be true"
    text = rpc.dig("result", "content", 0, "text")
    assert_match(/422/, text)
    assert_match(/Invalid date_from/, text)
  end

  test "member does not see admin tools" do
    access, _ = connect_agent(user: @member)
    rpc = mcp_call(access, "tools/list", {}, id: 1)
    names = rpc.dig("result", "tools").map { |t| t["name"] }
    assert_includes names, "send_message"
    refute_includes names, "list_users"
  end

  # ── gating ──────────────────────────────────────────────────────────────────
  test "master switch off rejects tool calls with a visible reason and logs them" do
    access, _ = connect_agent(user: @admin)
    @account.mcp_setting.update!(enabled: false)

    rpc = mcp_call(access, "tools/call", { name: "dashboard_stats", arguments: {} }, id: 1)
    # Rejections come back as an isError result (visible to the agent), not a
    # JSON-RPC error (which remote clients hide).
    assert_nil rpc["error"]
    assert rpc.dig("result", "isError")
    assert_match(/disabled/i, rpc.dig("result", "content", 0, "text"))
    assert_equal "rejected", @account.mcp_request_logs.order(:created_at).last.status
  end

  test "disabling the user blocks their connection" do
    access, _ = connect_agent(user: @admin)
    @admin.update!(mcp_enabled: false)

    rpc = mcp_call(access, "tools/call", { name: "dashboard_stats", arguments: {} }, id: 1)
    assert rpc.dig("result", "isError")
    assert_match(/disabled/i, rpc.dig("result", "content", 0, "text"))
  end

  # ── PKCE + refresh ──────────────────────────────────────────────────────────
  test "token endpoint rejects a tampered PKCE verifier" do
    code = authorize_and_consent(user: @admin)
    post "/oauth/token", params: {
      grant_type: "authorization_code", code: code, redirect_uri: @redirect_uri,
      code_verifier: "wrong-verifier", client_id: @client_id
    }
    assert_response :bad_request
    assert_equal "invalid_grant", JSON.parse(response.body)["error"]
  end

  test "refresh token rotates and the old one is revoked" do
    _access, refresh = connect_agent(user: @admin)

    post "/oauth/token", params: { grant_type: "refresh_token", refresh_token: refresh, client_id: @client_id }
    assert_response :success
    rotated = JSON.parse(response.body)
    assert rotated["access_token"].present?
    assert rotated["refresh_token"].present?

    # Old refresh token no longer works.
    post "/oauth/token", params: { grant_type: "refresh_token", refresh_token: refresh, client_id: @client_id }
    assert_response :bad_request
  end

  private

  # Registers a client, runs authorize→consent→token, returns [access, refresh].
  def connect_agent(user:)
    code = authorize_and_consent(user: user)
    post "/oauth/token", params: {
      grant_type: "authorization_code", code: code, redirect_uri: @redirect_uri,
      code_verifier: @verifier, client_id: @client_id
    }
    assert_response :success, "token exchange failed: #{response.body}"
    body = JSON.parse(response.body)
    [body["access_token"], body["refresh_token"]]
  end

  # DCR + authorize (GET redirect) + consent (POST) → returns the auth code.
  def authorize_and_consent(user:)
    post "/oauth/register", params: {
      client_name: "Test Agent", redirect_uris: [@redirect_uri]
    }
    assert_response :created
    @client_id = JSON.parse(response.body)["client_id"]

    query = {
      response_type: "code", client_id: @client_id, redirect_uri: @redirect_uri,
      scope: Mcp::Scopes.supported.join(" "), state: "xyz",
      code_challenge: @challenge, code_challenge_method: "S256"
    }
    get "/oauth/authorize", params: query
    assert_response :redirect
    assert_includes response.headers["Location"], "/oauth/consent"

    post "/oauth/authorize", params: query.merge(environment_id: @environment.id, approved: true),
                             headers: auth_headers(user)
    assert_response :success
    redirect_to = JSON.parse(response.body)["redirect_to"]
    CGI.parse(URI.parse(redirect_to).query)["code"].first
  end

  def mcp_call(access_token, method, params, id:)
    post "/mcp",
         params: { jsonrpc: "2.0", id: id, method: method, params: params },
         headers: { "Authorization" => "Bearer #{access_token}" },
         as: :json
    JSON.parse(response.body)
  end
end
