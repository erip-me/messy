require "test_helper"

# Pushleft App admin, protocol 1. Every request is signed here the way the
# Pushleft API signs it: one ES256 token per request, bound to the method, the
# path with its query string, and the SHA-256 of the body.
class PushleftAdminControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  PREFIX = "/_pushleft/admin".freeze
  AUDIENCE = "env_test_4f2a".freeze
  ENV_KEYS = %w[PUSHLEFT_ADMIN_JWKS PUSHLEFT_ADMIN_AUDIENCE].freeze

  setup do
    @key = OpenSSL::PKey::EC.generate("prime256v1")
    @saved_env = ENV_KEYS.index_with { |name| ENV[name] }
    ENV["PUSHLEFT_ADMIN_JWKS"] = { keys: [ JWT::JWK.new(@key, kid: "k1").export ] }.to_json
    ENV["PUSHLEFT_ADMIN_AUDIENCE"] = AUDIENCE
    ActiveJob::Base.queue_adapter = :test
  end

  teardown do
    @saved_env.each { |name, value| ENV[name] = value }
    ActiveJob::Base.queue_adapter = :solid_queue
  end

  # ── The signed request ───────────────────────────────────────────────────────

  test "a correctly signed request is accepted" do
    call("GET", "/schema")
    assert_response :success
  end

  test "no token is refused with 401 in the error shape" do
    get "#{PREFIX}/schema"

    assert_response :unauthorized
    assert_equal "unauthorized", response.parsed_body.dig("error", "code")
    assert response.parsed_body.dig("error", "message").present?
  end

  test "a signed-in user's own token is not an admin token" do
    get "#{PREFIX}/schema", headers: auth_headers(users(:admin))
    assert_response :unauthorized
  end

  test "alg none is refused" do
    call("GET", "/schema", token: JWT.encode(claims("GET", "#{PREFIX}/schema"), nil, "none", { kid: "k1" }))
    assert_response :unauthorized
  end

  test "a symmetric algorithm keyed with the public key is refused" do
    forged = JWT.encode(claims("GET", "#{PREFIX}/schema"), @key.public_to_pem, "HS256", { kid: "k1" })
    call("GET", "/schema", token: forged)
    assert_response :unauthorized
  end

  test "an unknown kid and a missing kid are refused" do
    call("GET", "/schema", token: sign("GET", "#{PREFIX}/schema", kid: "k2"))
    assert_response :unauthorized

    call("GET", "/schema", token: JWT.encode(claims("GET", "#{PREFIX}/schema"), @key, "ES256"))
    assert_response :unauthorized
  end

  test "a signature by another key is refused" do
    other = OpenSSL::PKey::EC.generate("prime256v1")
    call("GET", "/schema", token: sign("GET", "#{PREFIX}/schema", key: other))
    assert_response :unauthorized
  end

  test "another audience is refused" do
    call("GET", "/schema", token: sign("GET", "#{PREFIX}/schema", aud: "env_preview"))
    assert_response :unauthorized

    call("GET", "/schema", token: sign("GET", "#{PREFIX}/schema", aud: [ AUDIENCE, "env_preview" ]))
    assert_response :unauthorized
  end

  test "an expired token is refused, with 30 seconds of clock difference allowed" do
    call("GET", "/schema", token: sign("GET", "#{PREFIX}/schema", exp: Time.now.to_i - 31))
    assert_response :unauthorized

    call("GET", "/schema", token: sign("GET", "#{PREFIX}/schema", exp: Time.now.to_i - 20))
    assert_response :success
  end

  test "a token without exp is refused" do
    token = JWT.encode(claims("GET", "#{PREFIX}/schema").except(:exp), @key, "ES256", { kid: "k1" })
    call("GET", "/schema", token: token)
    assert_response :unauthorized
  end

  test "a token for another method is refused" do
    call("GET", "/accounts", token: sign("POST", "#{PREFIX}/accounts"))
    assert_response :unauthorized
  end

  test "a token for another path or another query string is refused" do
    call("GET", "/overview", token: sign("GET", "#{PREFIX}/schema"))
    assert_response :unauthorized

    call("GET", "/accounts?view=paying", token: sign("GET", "#{PREFIX}/accounts"))
    assert_response :unauthorized

    call("GET", "/accounts?view=paying", token: sign("GET", "#{PREFIX}/accounts?view=on_trial"))
    assert_response :unauthorized

    # The comparison is with the target as sent, not a decoded form of it.
    call("GET", "/accounts?view=on%5Ftrial", token: sign("GET", "#{PREFIX}/accounts?view=on_trial"))
    assert_response :unauthorized
  end

  test "a changed body is refused" do
    signed_for = { values: { name: "Signed" } }.to_json
    account = accounts(:acme)

    call("PATCH", "/accounts/#{account.id}", { values: { name: "Swapped" } },
         token: sign("PATCH", "#{PREFIX}/accounts/#{account.id}", signed_for))

    assert_response :unauthorized
    assert_equal "Acme Corp", account.reload.name
  end

  test "every path answers 404 when a variable is missing, even to a valid token" do
    ENV_KEYS.each do |missing|
      token = sign("GET", "#{PREFIX}/schema")
      saved = ENV[missing]
      ENV[missing] = nil

      call("GET", "/schema", token: token)
      assert_response :not_found, "with #{missing} unset"
      get "#{PREFIX}/accounts"
      assert_response :not_found
      post "#{PREFIX}/anything/at/all"
      assert_response :not_found
    ensure
      ENV[missing] = saved
    end
  end

  test "a malformed key set refuses instead of failing open" do
    token = sign("GET", "#{PREFIX}/schema")
    ENV["PUSHLEFT_ADMIN_JWKS"] = "{not json"

    call("GET", "/schema", token: token)
    assert_response :unauthorized
  end

  test "unknown paths under the prefix sit behind the token too" do
    get "#{PREFIX}/nothing/here/at/all"
    assert_response :unauthorized

    call("GET", "/nothing/here/at/all")
    assert_response :not_found
    assert_equal "not_found", response.parsed_body.dig("error", "code")

    call("PUT", "/accounts/#{accounts(:acme).id}", { values: {} })
    assert_response :not_found
  end

  test "malformed JSON is 400 with a token and 401 without" do
    path = "/accounts/#{accounts(:acme).id}"
    post "#{PREFIX}#{path}", params: "{oops", headers: { "Content-Type" => "application/json" }
    assert_response :unauthorized

    call("PATCH", path, "{oops")
    assert_response :bad_request
    assert_equal "bad_request", response.parsed_body.dig("error", "code")
  end

  test "a query string that cannot be parsed is 400 with a token and 401 without" do
    [ "/accounts?filter=x&filter[plan]=trial", "/accounts?q=%FF", "/schema?a=1&a[b]=2" ].each do |path|
      get "#{PREFIX}#{path}"
      assert_response :unauthorized, path

      call("GET", path)
      assert_response :bad_request, path
      assert_equal "bad_request", response.parsed_body.dig("error", "code"), path
    end
  end

  test "a write is logged with its actor" do
    lines = []
    Rails.logger.stubs(:info).with { |*args| lines << args.first.to_s if args.first; true }

    call("PATCH", "/users/#{users(:regular).id}", { values: { name: "Renamed" } },
         token: sign("PATCH", "#{PREFIX}/users/#{users(:regular).id}", { values: { name: "Renamed" } }.to_json,
                     sub: "ana@ops.example", role: "admin", jti: "req_123"))
    assert_response :success

    line = lines.grep(/\[PushleftAdmin\] write/).sole
    assert_includes line, 'sub="ana@ops.example"'
    assert_includes line, 'role="admin"'
    assert_includes line, 'jti="req_123"'
    assert_includes line, "PATCH #{PREFIX}/users/#{users(:regular).id} status=200"
  end

  # ── Schema and overview ──────────────────────────────────────────────────────

  test "schema describes the three resources in protocol 1" do
    schema = call("GET", "/schema")

    assert_equal 1, schema["protocol"]
    assert_equal "Messy", schema["title"]
    assert_equal true, schema["overview"]
    assert_equal %w[accounts users memberships], schema["resources"].map { |r| r["name"] }

    accounts, users, memberships = schema["resources"]
    assert_equal [ "Workspaces", "Workspace", "tenant" ], accounts.values_at("label", "singular", "kind")
    assert_equal %w[list show create update delete], accounts["can"]
    assert_equal true, accounts["search"]
    assert_equal %w[on_trial trial_ending trial_ended paying on_invoice], accounts["views"].map { |v| v["name"] }
    assert_equal [ { "resource" => "memberships", "field" => "account" } ], accounts["children"]
    assert_equal %w[extend_trial set_plan set_payment_status], accounts["actions"].map { |a| a["name"] }
    assert_equal "enum", field(accounts, "payment_status")["type"]
    assert_nil field(accounts, "payment_status")["update"]
    assert_equal true, field(users, "email")["update"]
    assert_equal %w[trial free byok managed],
                 field(accounts, "plan")["options"].map { |o| o["value"] }
    assert_equal "title", field(accounts, "name")["is"]
    assert_equal "trial_end", field(accounts, "trial_ends_at")["is"]
    assert_nil field(accounts, "stripe_customer_id")["update"]

    assert_equal "user", users["kind"]
    assert_equal %w[list show create update delete], users["can"]
    assert_equal %w[name email account role], users["fields"].select { |f| f["create"] }.map { |f| f["name"] }
    assert_equal %w[set_super_admin send_sign_in_link], users["actions"].map { |a| a["name"] }
    last_seen = users["fields"].select { |f| f["is"] == "last_seen" }
    assert_equal [ "last_login_at" ], last_seen.map { |f| f["name"] }
    assert_equal [ "datetime", true ], last_seen.first.values_at("type", "sort")

    assert_nil memberships["kind"]
    assert_equal %w[list show update delete], memberships["can"]
    assert_equal [ "ref", "accounts", true ], field(memberships, "account").values_at("type", "resource", "filter")
    assert_equal %w[member admin], field(memberships, "role")["options"].map { |o| o["value"] }

    # Only protocol keys leave the app.
    schema["resources"].each do |resource|
      assert_empty resource.keys - %w[name label singular kind can search views children fields actions]
      resource["fields"].each do |f|
        assert_empty f.keys - %w[name type label help required default list filter sort create update
                                 is group min max max_length unit options resource], f["name"]
      end
      resource["actions"].each { |a| assert_empty a.keys - %w[name label on input confirm danger] }
    end
  end

  test "overview counts workspaces, trials and sign-ins" do
    accounts(:acme).update!(trial_ends_at: 3.days.from_now)
    users(:regular).update!(last_login_at: 2.hours.ago)
    users(:other_user).update!(last_login_at: 3.days.ago)

    tiles = call("GET", "/overview")["tiles"]

    assert_equal [ "Workspaces", "On trial", "Trials ending within 7 days", "Users",
                   "Signed in during the last 24 hours" ], tiles.map { |t| t["label"] }
    assert_equal [ 2, 2, 1, 3, 1 ], tiles.map { |t| t["value"] }
    assert_equal({ "label" => "Trials ending within 7 days", "value" => 1,
                   "resource" => "accounts", "view" => "trial_ending" }, tiles[2])
    assert_equal [ "users", nil ], tiles[3].values_at("resource", "view")
  end

  # ── Lists ────────────────────────────────────────────────────────────────────

  test "a list item carries a string id, typed values and its actions" do
    acme_account = accounts(:acme)
    list = call("GET", "/accounts")

    assert_response :success
    assert_equal 2, list["total"]
    assert_nil list["next"]
    acme = list["items"].find { |i| i["id"] == accounts(:acme).id.to_s }
    assert_equal "Acme Corp", acme["values"]["name"]
    assert_equal "admin@acme.com", acme["values"]["owner_email"]
    assert_equal 2, acme["values"]["member_count"]
    assert_equal [ acme_account.environments.count, acme_account.templates.count,
                   acme_account.messages.where(created_at: 30.days.ago..).count ],
                 acme["values"].values_at("environment_count", "template_count", "messages_30d")
    assert_equal acme["values"], call("GET", "/accounts/#{acme_account.id}")["values"]
    assert_equal "pending_verification", acme["values"]["status"]
    assert_equal true, acme["values"]["chat_enabled"]
    assert_match(/\A\d{4}-\d\d-\d\dT\d\d:\d\d:\d\dZ\z/, acme["values"]["trial_ends_at"])
    assert_equal %w[extend_trial set_plan set_payment_status], acme["actions"]
  end

  test "show returns one item, and unknown ids and resources are 404" do
    membership = account_memberships(:regular_acme)
    item = call("GET", "/memberships/#{membership.id}")

    assert_equal membership.id.to_s, item["id"]
    assert_equal "regular@acme.com", item["values"]["email"]
    assert_equal({ "id" => accounts(:acme).id.to_s, "label" => "Acme Corp" }, item["values"]["account"])
    assert_equal({ "id" => users(:regular).id.to_s, "label" => "Regular User" }, item["values"]["user"])
    assert_equal [ "member", "active" ], item["values"].values_at("role", "state")

    [ "/memberships/0", "/memberships/abc", "/accounts/1%20OR%201=1", "/invoices", "/invoices/1" ].each do |path|
      call("GET", path)
      assert_response :not_found, path
      assert_equal "not_found", response.parsed_body.dig("error", "code")
    end
  end

  test "q searches, and treats LIKE wildcards as text" do
    assert_equal [ "Acme Corp" ], names(call("GET", "/accounts?q=acme"))
    assert_equal [], names(call("GET", "/accounts?q=%25"))
    assert_equal [ "Other User" ], names(call("GET", "/users?q=other.com"))
    assert_equal [ "Regular User" ], names(call("GET", "/users?q=regular"))

    call("GET", "/memberships?q=acme")
    assert_response :bad_request
  end

  test "views are named filters" do
    accounts(:acme).update!(trial_ends_at: 3.days.from_now)
    accounts(:other_co).update!(plan: "byok")

    assert_equal [ "Acme Corp" ], names(call("GET", "/accounts?view=on_trial"))
    assert_equal [ "Acme Corp" ], names(call("GET", "/accounts?view=trial_ending"))
    assert_equal [ "Other Company" ], names(call("GET", "/accounts?view=paying"))
    assert_equal [ "Other Company" ], names(call("GET", "/accounts?view=on_invoice"))
    accounts(:other_co).update!(stripe_subscription_id: "sub_1")
    assert_equal [], names(call("GET", "/accounts?view=on_invoice"))
    assert_equal [], names(call("GET", "/accounts?view=trial_ended"))

    accounts(:acme).update!(trial_ends_at: 1.day.ago)
    assert_equal [ "Acme Corp" ], names(call("GET", "/accounts?view=trial_ended"))
    assert_equal [], names(call("GET", "/accounts?view=on_trial"))

    call("GET", "/accounts?view=nope")
    assert_response :bad_request
  end

  test "filters match any of the values and take date ranges" do
    accounts(:other_co).update!(plan: "byok", trial_ends_at: 2.days.from_now)
    soon = 7.days.from_now.utc.iso8601

    assert_equal [ "Other Company" ], names(call("GET", "/accounts?filter[plan]=free,byok"))
    assert_equal 2, call("GET", "/accounts?filter%5Bplan%5D=trial,byok")["total"]
    assert_equal [ "Other Company" ], names(call("GET", "/accounts?filter[trial_ends_at][lte]=#{soon}"))
    assert_equal [ "Acme Corp" ], names(call("GET", "/accounts?filter[trial_ends_at][gte]=#{soon}"))
    assert_equal [ "Acme Corp" ], names(call("GET", "/accounts?filter[chat_enabled]=true&filter[plan]=trial"))
    assert_equal [ "Admin User" ], names(call("GET", "/users?filter[is_super_admin]=true"))
  end

  test "memberships filter by workspace, user, role and state" do
    invite_to_workspace(users(:other_user), accounts(:acme), role: :admin)
    acme = accounts(:acme).id

    assert_equal 3, call("GET", "/memberships?filter[account]=#{acme}")["total"]
    assert_equal %w[user@other.com],
                 call("GET", "/memberships?filter[account]=#{acme}&filter[state]=invited")["items"].map { |i| i["values"]["email"] }
    assert_equal 2, call("GET", "/memberships?filter[account]=#{acme}&filter[state]=active")["total"]
    assert_equal 4, call("GET", "/memberships?filter[state]=active,invited")["total"]
    assert_equal 2, call("GET", "/memberships?filter[user]=#{users(:other_user).id}")["total"]
    assert_equal 1, call("GET", "/memberships?filter[role]=member")["total"]
  end

  test "filters outside the schema are 400 and never reach SQL" do
    [
      "filter[name]=Acme",                    # not marked filterable
      "filter[password]=x",                   # not a field
      "filter[plan]=enterprise",              # not an option
      "filter[plan][gte]=a",                  # ranges are for dates and numbers
      "filter[trial_ends_at][gt]=2026-01-01T00:00:00Z",
      "filter[trial_ends_at][gte]=yesterday",
      "filter[chat_enabled]=yes",
      "filter[plan][]=trial",
      "filter=plan",
      "sort=plan",                            # not marked sortable
      "sort=name;drop",
      "limit=0",
      "limit=ten",
      "after=not-a-cursor",
      "view[]=on_trial"
    ].each do |query|
      call("GET", "/accounts?#{query}")
      assert_response :bad_request, query
      assert_equal "bad_request", response.parsed_body.dig("error", "code"), query
    end

    call("GET", "/memberships?filter[account]=1%20OR%201=1")
    assert_response :bad_request

    # No filter takes free text: a value is an option, a boolean, a number or a date.
    call("GET", "/accounts?filter[payment_status]=x'%20OR%20'1'='1")
    assert_response :bad_request
    assert_equal 2, call("GET", "/accounts?filter[payment_status]=active")["total"]
  end

  test "users are listed by last sign-in, newest first, and sort on marked fields" do
    users(:regular).update!(last_login_at: 1.hour.ago)
    users(:other_user).update!(last_login_at: 2.hours.ago)

    assert_equal [ "Regular User", "Other User", "Admin User" ], names(call("GET", "/users"))
    assert_equal [ "Admin User", "Regular User", "Other User" ], names(call("GET", "/users?sort=email"))
    assert_equal [ "Other User", "Regular User", "Admin User" ], names(call("GET", "/users?sort=-email"))
    assert_equal [ "Other User", "Regular User", "Admin User" ], names(call("GET", "/users?sort=last_login_at"))

    call("GET", "/users?sort=is_super_admin")
    assert_response :bad_request
  end

  test "lists page with limit and an opaque cursor" do
    first = call("GET", "/users?sort=email&limit=2")
    assert_equal [ "Admin User", "Regular User" ], names(first)
    assert_equal 3, first["total"]
    assert first["next"].present?

    second = call("GET", "/users?sort=email&limit=2&after=#{first['next']}")
    assert_equal [ "Other User" ], names(second)
    assert_nil second["next"]

    assert_equal 3, call("GET", "/users?limit=5000")["items"].size
  end

  # ── Create, update, delete ───────────────────────────────────────────────────

  test "create makes a workspace with its first admin and mails a sign-in link" do
    answer = nil
    assert_difference [ "Account.count", "User.count", "AccountMembership.count" ], 1 do
      assert_enqueued_emails 1 do
        answer = call("POST", "/accounts",
                      { values: { name: "Lumen Labs", owner_email: " Ana@Lumen.example ", owner_name: "Ana" } })
      end
    end

    assert_response :success
    account = Account.find(answer["item"]["id"])
    user = User.find_by!(email: "ana@lumen.example")
    assert_equal [ "Lumen Labs", "trial", "pending_verification" ], [ account.name, account.plan, account.status ]
    assert_in_delta 14.days.from_now, account.trial_ends_at, 1.minute
    assert user.membership_for(account).admin?
    assert user.member_of?(account)
    assert user.magic_link_token.present?
    assert_equal "ana@lumen.example", answer["item"]["values"]["owner_email"]
    assert_includes answer["message"], "ana@lumen.example"
    assert_nil answer["reveal"]
  end

  test "create takes a plan and a trial end" do
    ends = 30.days.from_now.utc.iso8601
    answer = call("POST", "/accounts", { values: { name: "Paid Co", owner_email: "p@paid.example",
                                                   owner_name: "P", plan: "byok", trial_ends_at: ends } })

    assert_response :success
    assert_equal [ "byok", ends ], answer["item"]["values"].values_at("plan", "trial_ends_at")
    assert_equal %w[set_plan set_payment_status], answer["item"]["actions"]
  end

  test "create refuses invalid values with a message per field and creates nothing" do
    {
      { name: "No owner" } => %w[owner_email owner_name],
      { name: "", owner_email: "a@b.example", owner_name: "A" } => %w[name],
      { name: "Dup", owner_email: "admin@acme.com", owner_name: "A" } => %w[owner_email],
      { name: "Bad mail", owner_email: "not-an-address", owner_name: "A" } => %w[owner_email],
      { name: "Bad plan", owner_email: "a@b.example", owner_name: "A", plan: "gold" } => %w[plan],
      { name: "Bad time", owner_email: "a@b.example", owner_name: "A", trial_ends_at: "soon" } => %w[trial_ends_at],
      { name: "Extra", owner_email: "a@b.example", owner_name: "A", status: "active" } => %w[status],
      { name: [ "x" ], owner_email: "a@b.example", owner_name: "A" } => %w[name],
      { name: "x" * 256, owner_email: "a@b.example", owner_name: "A" } => %w[name]
    }.each do |values, fields|
      assert_no_difference [ "Account.count", "User.count" ], values.inspect do
        call("POST", "/accounts", { values: values })
      end
      assert_response :unprocessable_entity, values.inspect
      assert_equal "invalid", response.parsed_body.dig("error", "code")
      assert_equal fields, response.parsed_body.dig("error", "fields").keys, values.inspect
    end

    call("POST", "/accounts", { values: "name" })
    assert_response :bad_request
    call("POST", "/accounts", [ 1 ])
    assert_response :bad_request
  end

  test "create makes a user in one workspace and mails a sign-in link" do
    acme = accounts(:acme)
    answer = nil
    assert_difference [ "User.count", "AccountMembership.count" ], 1 do
      assert_enqueued_emails 1 do
        answer = call("POST", "/users", { values: { name: "Ana", email: " Ana@Lumen.example ",
                                                    account: acme.id.to_s, role: "admin" } })
      end
    end

    assert_response :success
    user = User.find(answer["item"]["id"])
    assert_equal [ "ana@lumen.example", acme.id, false ], [ user.email, user.account_id, user.is_super_admin ]
    assert user.membership_for(acme).admin?
    assert user.magic_link_token.present?
    assert_equal [ { "id" => acme.id.to_s, "label" => "Acme Corp" }, "admin" ],
                 answer["item"]["values"].values_at("account", "role")
    assert_includes answer["message"], "ana@lumen.example"

    call("POST", "/users", { values: { name: "Bo", email: "bo@lumen.example", account: acme.id.to_s } })
    assert_equal "member", response.parsed_body.dig("item", "values", "role")
  end

  test "create refuses a user without a real workspace, with a taken address or with more than the form" do
    acme = accounts(:acme).id.to_s
    {
      { name: "X", email: "x@x.example" } => "account",
      { name: "X", email: "x@x.example", account: "0" } => "account",
      { name: "X", email: "x@x.example", account: accounts(:acme).id } => "account",
      { name: "X", email: "x@x.example", account: "1 OR 1=1" } => "account",
      { name: "X", email: "regular@acme.com", account: acme } => "email",
      { name: "X", email: "not an address", account: acme } => "email",
      { name: "X", email: "x@x.example", account: acme, role: "owner" } => "role",
      { name: "X", email: "x@x.example", account: acme, is_super_admin: true } => "is_super_admin"
    }.each do |values, field|
      assert_no_difference [ "User.count", "AccountMembership.count" ], values.inspect do
        call("POST", "/users", { values: values })
      end
      assert_response :unprocessable_entity, values.inspect
      assert_equal [ field ], response.parsed_body.dig("error", "fields").keys
    end
  end

  test "memberships are not created here" do
    assert_no_difference "AccountMembership.count" do
      call("POST", "/memberships", { values: { account: accounts(:acme).id.to_s } })
      assert_response :not_found
    end
  end

  test "update changes only the fields marked for it" do
    account = accounts(:acme)
    answer = call("PATCH", "/accounts/#{account.id}",
                  { values: { name: "Acme BV", message_retention_days: 90, chat_enabled: false } })

    assert_response :success
    assert_equal [ "Acme BV", 90, false ],
                 answer["item"]["values"].values_at("name", "message_retention_days", "chat_enabled")
    assert_equal [ "Acme BV", 90, false ], account.reload.then { |a| [ a.name, a.message_retention_days, a.chat_enabled ] }

    {
      { plan: "byok" } => "plan",
      { status: "active" } => "status",
      { stripe_customer_id: "cus_1" } => "stripe_customer_id",
      { message_retention_days: 45 } => "message_retention_days",
      { message_retention_days: 9000 } => "message_retention_days",
      { message_retention_days: "90" } => "message_retention_days",
      { chat_enabled: nil } => "chat_enabled",
      { name: nil } => "name"
    }.each do |values, field|
      call("PATCH", "/accounts/#{account.id}", { values: values })
      assert_response :unprocessable_entity, values.inspect
      assert_equal [ field ], response.parsed_body.dig("error", "fields").keys
    end
    assert_equal [ "Acme BV", "trial", "pending_verification", nil ],
                 account.reload.then { |a| [ a.name, a.plan, a.status, a.stripe_customer_id ] }
  end

  test "a user's name and MCP switch can be changed, the super admin flag cannot" do
    user = users(:regular)
    assert_no_enqueued_emails do
      call("PATCH", "/users/#{user.id}", { values: { name: "Reg", mcp_enabled: false, email: "Regular@Acme.com" } })
    end
    assert_response :success
    assert_nil response.parsed_body["message"]
    assert_equal [ "Reg", false, "regular@acme.com" ], user.reload.then { |u| [ u.name, u.mcp_enabled, u.email ] }

    call("PATCH", "/users/#{user.id}", { values: { is_super_admin: true } })
    assert_response :unprocessable_entity
    assert_equal false, user.reload.is_super_admin
  end

  test "a user's email moves: old sign-in links stop working and the old address gets a notice" do
    user = users(:regular)
    user.generate_magic_link_token!

    answer = nil
    assert_enqueued_emails 1 do
      answer = call("PATCH", "/users/#{user.id}", { values: { email: " New.Address@Acme.com " } })
    end
    assert_response :success
    assert_equal "new.address@acme.com", answer["item"]["values"]["email"]
    assert_match(/regular@acme\.com/, answer["message"])
    assert_equal [ "new.address@acme.com", nil ], user.reload.then { |u| [ u.email, u.magic_link_token ] }
    notice = enqueued_jobs.last["arguments"]
    assert_equal "email_changed_notice", notice[1]
    assert_includes notice.to_json, "regular@acme.com"
  end

  test "a user's email does not move to a taken, malformed or empty address" do
    user = users(:regular)
    user.generate_magic_link_token!

    assert_no_enqueued_emails do
      [ "admin@acme.com", "ADMIN@acme.com", "not-an-address", "", nil, [ "a@b.example" ] ].each do |email|
        call("PATCH", "/users/#{user.id}", { values: { email: email } })
        assert_response :unprocessable_entity, email.inspect
        assert_equal [ "email" ], response.parsed_body.dig("error", "fields").keys
      end
    end
    assert_equal "regular@acme.com", user.reload.email
    assert user.magic_link_token.present?
  end

  test "a membership role changes, but the last admin is not demoted" do
    regular, admin = account_memberships(:regular_acme), account_memberships(:admin_acme)

    call("PATCH", "/memberships/#{admin.id}", { values: { role: "member" } })
    assert_response :conflict
    assert_equal "conflict", response.parsed_body.dig("error", "code")
    assert_match(/last admin/, response.parsed_body.dig("error", "message"))
    assert admin.reload.admin?

    answer = call("PATCH", "/memberships/#{regular.id}", { values: { role: "admin" } })
    assert_response :success
    assert_equal "admin", answer["item"]["values"]["role"]

    call("PATCH", "/memberships/#{admin.id}", { values: { role: "member" } })
    assert_response :success
    assert admin.reload.member?

    call("PATCH", "/memberships/#{regular.id}", { values: { role: "owner" } })
    assert_response :unprocessable_entity
  end

  test "an invited admin does not count as cover for the last admin" do
    invite_to_workspace(users(:regular), accounts(:other_co), role: :admin)

    call("PATCH", "/memberships/#{account_memberships(:other_user_other_co).id}", { values: { role: "member" } })
    assert_response :conflict
  end

  test "deleting a workspace follows the existing admin API" do
    created = call("POST", "/accounts", { values: { name: "Gone", owner_email: "g@gone.example", owner_name: "G" } })

    assert_difference [ "Account.count", "User.count" ], -1 do
      answer = call("DELETE", "/accounts/#{created['item']['id']}")
      assert_response :success
      assert_equal "Workspace deleted", answer["message"]
    end
  end

  test "deleting a user removes the login and its memberships" do
    assert_difference [ "User.count", "AccountMembership.count" ], -1 do
      answer = call("DELETE", "/users/#{users(:regular).id}")
      assert_response :success
      assert_equal "User deleted", answer["message"]
    end
  end

  test "the last super admin and the last admin of a workspace are not deleted" do
    assert_no_difference [ "User.count", "AccountMembership.count" ] do
      call("DELETE", "/users/#{users(:admin).id}")
      assert_response :conflict
      assert_match(/last super admin/, response.parsed_body.dig("error", "message"))

      call("DELETE", "/users/#{users(:other_user).id}")
      assert_response :conflict
      assert_match(/last admin/, response.parsed_body.dig("error", "message"))
    end

    # With another super admin, the first one is still Acme's only admin.
    users(:other_user).update!(is_super_admin: true)
    call("DELETE", "/users/#{users(:admin).id}")
    assert_response :conflict
    assert_match(/last admin/, response.parsed_body.dig("error", "message"))
  end

  test "removing a membership keeps the login while the person has another workspace" do
    user = users(:regular)
    join_workspace(user, accounts(:other_co))

    assert_difference "AccountMembership.count", -1 do
      assert_no_difference "User.count" do
        call("DELETE", "/memberships/#{account_memberships(:regular_acme).id}")
      end
    end

    assert_response :success
    assert_includes response.parsed_body["message"], "regular@acme.com was removed from Acme Corp"
    assert_equal accounts(:other_co).id, user.reload.account_id
  end

  test "removing a person's last membership deletes the login and says so" do
    assert_difference [ "AccountMembership.count", "User.count" ], -1 do
      call("DELETE", "/memberships/#{account_memberships(:regular_acme).id}")
    end

    assert_response :success
    assert_includes response.parsed_body["message"], "login was deleted"
  end

  test "the last admin's membership is not removed" do
    assert_no_difference [ "AccountMembership.count", "User.count" ] do
      call("DELETE", "/memberships/#{account_memberships(:other_user_other_co).id}")
    end

    assert_response :conflict
    assert_match(/last admin/, response.parsed_body.dig("error", "message"))
  end

  # ── Actions ──────────────────────────────────────────────────────────────────

  test "extend_trial moves the trial end" do
    account = accounts(:acme)
    later = 60.days.from_now.utc.change(usec: 0)

    answer = call("POST", "/accounts/#{account.id}/actions/extend_trial", { input: { until: later.iso8601 } })

    assert_response :success
    assert_equal later, account.reload.trial_ends_at
    assert_equal later.iso8601, answer["item"]["values"]["trial_ends_at"]
    assert answer["message"].present?
  end

  test "extend_trial refuses a past, missing or malformed date, and a workspace that is not on trial" do
    account = accounts(:acme)
    was = account.trial_ends_at

    [ { until: 1.day.ago.utc.iso8601 }, {}, { until: "next month" }, { until: nil }, { until: 5 } ].each do |input|
      call("POST", "/accounts/#{account.id}/actions/extend_trial", { input: input })
      assert_response :unprocessable_entity, input.inspect
      assert_equal [ "until" ], response.parsed_body.dig("error", "fields").keys
    end
    assert_equal was, account.reload.trial_ends_at

    account.update!(plan: "byok")
    call("POST", "/accounts/#{account.id}/actions/extend_trial", { input: { until: 60.days.from_now.utc.iso8601 } })
    assert_response :conflict
    assert_equal %w[set_plan set_payment_status], call("GET", "/accounts/#{account.id}")["actions"]
  end

  test "set_plan takes only a real plan" do
    account = accounts(:acme)

    answer = call("POST", "/accounts/#{account.id}/actions/set_plan", { input: { plan: "byok" } })
    assert_response :success
    assert_equal "byok", account.reload.plan
    assert_equal "byok", answer["item"]["values"]["plan"]

    [ { plan: "pro" }, { plan: "" }, {}, { plan: "free", extra: 1 } ].each do |input|
      call("POST", "/accounts/#{account.id}/actions/set_plan", { input: input })
      assert_response :unprocessable_entity, input.inspect
    end
    assert_equal "byok", account.reload.plan
  end

  test "set_payment_status records an invoice payment, and leaves a Stripe subscription to Stripe" do
    account = accounts(:other_co)
    account.update!(plan: "managed", payment_status: nil)
    path = "/accounts/#{account.id}/actions/set_payment_status"

    answer = call("POST", path, { input: { payment_status: "past_due" } })
    assert_response :success
    assert_equal "past_due", account.reload.payment_status
    assert_equal "past_due", answer["item"]["values"]["payment_status"]
    assert_equal [ "Other Company" ], names(call("GET", "/accounts?filter[payment_status]=past_due"))

    # Only what a person decides for an invoice, not every state Stripe knows.
    [ { payment_status: "unpaid" }, { payment_status: "paid" }, { payment_status: 1 }, { status: "active" } ].each do |input|
      call("POST", path, { input: input })
      assert_response :unprocessable_entity, input.inspect
    end
    assert_equal "past_due", account.reload.payment_status

    call("POST", path, { input: {} })
    assert_response :success
    assert_nil account.reload.payment_status

    account.update!(stripe_subscription_id: "sub_1", payment_status: "active")
    call("POST", path, { input: { payment_status: "canceled" } })
    assert_response :conflict
    assert_equal "active", account.reload.payment_status
    assert_equal %w[set_plan], call("GET", "/accounts/#{account.id}")["actions"]
  end

  test "set_super_admin grants and removes, but never removes the last one" do
    admin, regular = users(:admin), users(:regular)

    call("POST", "/users/#{admin.id}/actions/set_super_admin", { input: { super_admin: false } })
    assert_response :conflict
    assert_match(/last super admin/, response.parsed_body.dig("error", "message"))
    assert admin.reload.is_super_admin?

    answer = call("POST", "/users/#{regular.id}/actions/set_super_admin", { input: { super_admin: true } })
    assert_response :success
    assert_equal true, answer["item"]["values"]["is_super_admin"]
    assert regular.reload.is_super_admin?

    call("POST", "/users/#{admin.id}/actions/set_super_admin", { input: { super_admin: false } })
    assert_response :success
    assert_not admin.reload.is_super_admin?

    [ { super_admin: "true" }, { super_admin: 1 }, {}, { super_admin: nil } ].each do |input|
      call("POST", "/users/#{admin.id}/actions/set_super_admin", { input: input })
      assert_response :unprocessable_entity, input.inspect
    end
    assert_not admin.reload.is_super_admin?
  end

  test "send_sign_in_link mails a fresh link" do
    user = users(:regular)

    assert_enqueued_emails 1 do
      answer = call("POST", "/users/#{user.id}/actions/send_sign_in_link")
      assert_response :success
      assert_includes answer["message"], "regular@acme.com"
    end
    assert user.reload.magic_link_token_valid?
  end

  test "unknown actions are 404" do
    account = accounts(:acme)

    [ "/accounts/#{account.id}/actions/suspend", "/accounts/#{account.id}/actions/destroy",
      "/accounts/#{account.id}/actions/set_super_admin", "/accounts/actions/set_plan",
      "/accounts/0/actions/set_plan", "/memberships/#{account_memberships(:admin_acme).id}/actions/set_role" ].each do |path|
      call("POST", path, { input: {} })
      assert_response :not_found, path
    end
    assert_equal "pending_verification", account.reload.status
  end

  private

  def claims(method, path, body = "", **overrides)
    now = Time.now.to_i
    { iss: "https://api.pushleft.dev", aud: AUDIENCE, sub: "ops@example.com", role: "owner",
      iat: now, exp: now + 60, jti: SecureRandom.uuid,
      method: method, path: path, body: Digest::SHA256.hexdigest(body) }.merge(overrides)
  end

  def sign(method, path, body = "", key: @key, kid: "k1", **overrides)
    JWT.encode(claims(method, path, body, **overrides), key, "ES256", { kid: kid })
  end

  # Sends a request signed for exactly what is sent, unless a token is given.
  # Returns the parsed answer.
  def call(method, path, body = nil, token: nil)
    raw = body.nil? || body.is_a?(String) ? body.to_s : body.to_json
    headers = { "Authorization" => "Bearer #{token || sign(method, "#{PREFIX}#{path}", raw)}" }
    headers["Content-Type"] = "application/json" unless body.nil?

    public_send(method.downcase, "#{PREFIX}#{path}", params: (raw unless body.nil?), headers: headers)
    response.parsed_body
  end

  def field(resource, name)
    resource["fields"].find { |f| f["name"] == name }
  end

  def names(list)
    list["items"].map { |item| item["values"]["name"] }
  end
end
