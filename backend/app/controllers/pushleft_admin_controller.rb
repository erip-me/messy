# Pushleft App admin, protocol version 1: the operator back office of this
# installation, called by the Pushleft console on behalf of a signed-in person.
#
# Off unless PUSHLEFT_ADMIN_JWKS (a JSON Web Key Set, public keys only) and
# PUSHLEFT_ADMIN_AUDIENCE are set: without them every path under the prefix
# answers 404, which is what a self-hosted install without Pushleft gets. With
# them, every request must carry a token that was signed for that one request
# (see #verified_claims). The app holds no secret.
#
# Deliberately not an ApplicationController: the user JWT, the API keys and the
# workspace resolution do not apply here.
class PushleftAdminController < ActionController::API
  class Refusal < StandardError
    attr_reader :status, :code, :fields

    def initialize(status, code, message, fields = nil)
      super(message)
      @status, @code, @fields = status, code, fields
    end
  end

  LAST_ADMIN = "The last admin of a workspace cannot be removed or demoted".freeze

  PLAN_OPTIONS = ([ { value: "trial", label: "Trial" } ] +
                  Account::PLANS.map { |key, plan| { value: key, label: plan[:name] } }).freeze

  # Stripe writes the payment status of a workspace with a subscription. For one
  # that pays by invoice, a person sets one of the first three by hand.
  INVOICE_STATUSES = [ { value: "active", label: "Paid", tone: "good" },
                       { value: "past_due", label: "Past due", tone: "warn" },
                       { value: "canceled", label: "Canceled", tone: "bad" } ].freeze
  PAYMENT_OPTIONS = (INVOICE_STATUSES + %w[unpaid incomplete incomplete_expired paused].map do |status|
    { value: status, label: status.humanize, tone: "warn" }
  end).freeze

  FIRST_ADMIN = ->(account) { account.accepted_memberships.select(&:admin?).min_by(&:id)&.user }

  # What /schema publishes of a resource, a field and an action. Every other key
  # in RESOURCES (model, scopes, readers) stays inside the app.
  RESOURCE_KEYS = %i[name label singular kind can search children].freeze
  FIELD_KEYS = %i[name type label help required default list filter sort create update is group
                  min max max_length unit options resource].freeze
  ACTION_KEYS = %i[name label on input confirm danger].freeze

  # The whole surface, declared once. Lists filter and sort only on what is
  # marked here, and writes touch only fields marked `create` or `update`.
  # Internal keys: `column` (when it differs from the name), `read` (a computed
  # value), `count` (a number per record, counted for a whole page in one
  # query), `where` (a filter that is not a plain column match), `available`
  # (whether an action applies to an item now).
  RESOURCES = [
    {
      name: "accounts", label: "Workspaces", singular: "Workspace", kind: "tenant",
      can: %w[list show create update delete], search: true,
      model: Account, preload: { accepted_memberships: :user }, default_sort: "-created_at",
      search_scope: ->(scope, like) { scope.where("accounts.name ILIKE ?", like) },
      views: [
        { name: "on_trial", label: "On trial",
          scope: ->(s) { s.where(plan: "trial").where("trial_ends_at IS NULL OR trial_ends_at > ?", Time.current) } },
        { name: "trial_ending", label: "Trial ends this week",
          scope: ->(s) { s.where(plan: "trial", trial_ends_at: Time.current..7.days.from_now) } },
        { name: "trial_ended", label: "Trial ended",
          scope: ->(s) { s.where(plan: "trial", trial_ends_at: ..Time.current) } },
        { name: "paying", label: "Paying", scope: ->(s) { s.where(plan: Account::PAID_PLANS) } },
        { name: "on_invoice", label: "Pays by invoice",
          scope: ->(s) { s.where(plan: Account::PAID_PLANS, stripe_subscription_id: nil) } }
      ],
      children: [ { resource: "memberships", field: "account" } ],
      fields: [
        { name: "name", type: "string", is: "title", required: true, max_length: 255,
          sort: true, create: true, update: true },
        { name: "owner_email", type: "email", label: "First admin", is: "subtitle", required: true,
          max_length: 254, create: true, help: "Gets a sign-in link by mail.",
          read: ->(a) { FIRST_ADMIN.call(a)&.email } },
        { name: "owner_name", type: "string", label: "First admin name", required: true,
          max_length: 255, create: true, read: ->(a) { FIRST_ADMIN.call(a)&.name } },
        { name: "status", type: "enum", is: "status", list: true, filter: true,
          options: [ { value: "pending_verification", label: "Pending verification", tone: "warn" },
                     { value: "active", label: "Active", tone: "good" },
                     { value: "suspended", label: "Suspended", tone: "bad" } ] },
        { name: "plan", type: "enum", list: true, filter: true, create: true, default: "trial",
          options: PLAN_OPTIONS, help: "Changed afterwards with Set plan." },
        { name: "trial_ends_at", type: "datetime", label: "Trial ends", is: "trial_end", list: true,
          sort: true, filter: true, create: true,
          help: "Left empty, a new trial runs for 14 days. Changed afterwards with Extend trial." },
        { name: "member_count", type: "integer", label: "Members", list: true,
          read: ->(a) { a.accepted_memberships.size } },
        { name: "environment_count", type: "integer", label: "Environments", group: "Usage",
          count: ->(ids) { Environment.where(account_id: ids).group(:account_id).count } },
        { name: "template_count", type: "integer", label: "Templates", group: "Usage",
          count: ->(ids) { Template.where(account_id: ids).group(:account_id).count } },
        # ponytail: counted for every page of the list, on the (account_id,
        # created_at) index. Keep a counter per workspace if a page gets slow.
        { name: "messages_30d", type: "integer", label: "Messages, last 30 days", group: "Usage",
          count: ->(ids) { Message.where(account_id: ids, created_at: 30.days.ago..).group(:account_id).count } },
        { name: "message_retention_days", type: "integer", label: "Message retention", unit: "days",
          min: 30, max: 180, update: true, help: "30, 60, 90 or 180." },
        { name: "chat_enabled", type: "boolean", filter: true, update: true },
        { name: "payment_status", type: "enum", group: "Billing", list: true, filter: true,
          options: PAYMENT_OPTIONS, help: "Stripe keeps it for a subscription. Set by hand for an invoice." },
        { name: "stripe_customer_id", type: "string", label: "Stripe customer", group: "Billing" },
        { name: "stripe_subscription_id", type: "string", label: "Stripe subscription", group: "Billing" },
        { name: "subscription_current_period_end", type: "datetime", label: "Current period ends",
          group: "Billing" },
        { name: "subscription_cancel_at_period_end", type: "boolean", label: "Cancels at period end",
          group: "Billing" },
        { name: "created_at", type: "datetime", label: "Created", list: true, sort: true, filter: true }
      ],
      actions: [
        { name: "extend_trial", label: "Extend trial", on: "item",
          input: [ { name: "until", type: "datetime", required: true } ],
          available: ->(a) { a.trial? } },
        { name: "set_plan", label: "Set plan", on: "item",
          confirm: "This changes the plan in Messy only. A Stripe subscription stays as it is.",
          input: [ { name: "plan", type: "enum", required: true, options: PLAN_OPTIONS } ] },
        # A workspace on a contract pays by invoice, outside Stripe: Set plan
        # puts it on its plan, and this records whether the invoice is paid.
        { name: "set_payment_status", label: "Set payment status", on: "item",
          confirm: "For a workspace that pays by invoice. Its billing page shows the status.",
          input: [ { name: "payment_status", type: "enum", options: INVOICE_STATUSES,
                     help: "Left empty, the status is cleared." } ],
          # With a subscription, Stripe's next invoice would overwrite it.
          available: ->(a) { a.stripe_subscription_id.blank? } }
      ]
    },
    {
      name: "users", label: "Users", singular: "User", kind: "user",
      can: %w[list show create update delete], search: true,
      model: User, preload: %i[account account_memberships], default_sort: "-last_login_at",
      search_scope: ->(scope, like) { scope.where("users.name ILIKE :q OR users.email ILIKE :q", q: like) },
      views: [
        { name: "signed_in_24h", label: "Signed in, last 24 hours",
          scope: ->(s) { s.where(last_login_at: 24.hours.ago..) } }
      ],
      children: [ { resource: "memberships", field: "user" } ],
      fields: [
        { name: "name", type: "string", is: "title", required: true, max_length: 255,
          sort: true, create: true, update: true },
        { name: "email", type: "email", is: "subtitle", required: true, max_length: 254, sort: true,
          create: true, update: true,
          help: "The sign-in address. After a change, the old address gets a notice." },
        { name: "account", type: "ref", resource: "accounts", label: "Workspace", required: true,
          list: true, filter: true, create: true,
          column: "account_id", help: "The workspace this person opens by default.",
          read: ->(u) { { id: u.account_id.to_s, label: u.account.name } } },
        { name: "role", type: "enum", create: true, default: "member",
          options: [ { value: "member", label: "Member" }, { value: "admin", label: "Admin" } ],
          help: "In the default workspace. Changed per workspace under Memberships.",
          read: ->(u) { u.account_memberships.find { |m| m.account_id == u.account_id }&.role } },
        { name: "is_super_admin", type: "boolean", label: "Super admin", list: true, filter: true },
        { name: "email_verified", type: "boolean", filter: true },
        { name: "mcp_enabled", type: "boolean", label: "MCP enabled", filter: true, update: true },
        { name: "last_login_at", type: "datetime", label: "Last sign-in", is: "last_seen", list: true,
          sort: true, filter: true },
        { name: "created_at", type: "datetime", label: "Created", list: true, sort: true, filter: true }
      ],
      actions: [
        { name: "set_super_admin", label: "Set super admin", on: "item",
          confirm: "A super admin can open and change every workspace.",
          input: [ { name: "super_admin", type: "boolean", required: true } ] },
        { name: "send_sign_in_link", label: "Send sign-in link", on: "item" }
      ]
    },
    {
      name: "memberships", label: "Memberships", singular: "Membership",
      can: %w[list show update delete],
      model: AccountMembership, preload: %i[user account], default_sort: "-created_at",
      views: [],
      fields: [
        { name: "email", type: "email", is: "title", read: ->(m) { m.user.email } },
        { name: "account", type: "ref", resource: "accounts", label: "Workspace", list: true, filter: true,
          column: "account_id", read: ->(m) { { id: m.account_id.to_s, label: m.account.name } } },
        { name: "user", type: "ref", resource: "users", filter: true,
          column: "user_id", read: ->(m) { { id: m.user_id.to_s, label: m.user.name } } },
        { name: "role", type: "enum", list: true, filter: true, update: true,
          options: [ { value: "member", label: "Member" }, { value: "admin", label: "Admin" } ] },
        { name: "state", type: "enum", is: "status", list: true, filter: true,
          options: [ { value: "invited", label: "Invited", tone: "warn" },
                     { value: "active", label: "Active", tone: "good" } ],
          read: ->(m) { m.accepted? ? "active" : "invited" },
          where: lambda do |scope, states|
            next scope if states.uniq.size > 1
            states.first == "active" ? scope.accepted : scope.pending
          end },
        { name: "accepted_at", type: "datetime", label: "Accepted" },
        { name: "created_at", type: "datetime", label: "Created", list: true, sort: true }
      ],
      actions: []
    }
  ].freeze

  before_action :authenticate

  rescue_from(Refusal) { |e| render_error(e.status, e.code, e.message, e.fields) }
  rescue_from(ActiveRecord::RecordNotFound) { render_error(404, "not_found", "Not found") }
  # Two writes of one address at the same moment: the index refuses the second.
  rescue_from(ActiveRecord::RecordNotUnique) { render_error(409, "conflict", "That value is already taken") }
  rescue_from(ActiveRecord::RecordNotDestroyed, ActiveRecord::InvalidForeignKey) do
    render_error(409, "conflict", "This record is still in use and cannot be deleted")
  end
  rescue_from(ActiveRecord::RecordInvalid) do |e|
    # A new workspace is created together with its first admin, whose errors
    # belong under the owner_* inputs.
    prefix = e.record.is_a?(User) && request.path_parameters[:resource] == "accounts" ? "owner_" : ""
    render_error(422, "invalid", e.record.errors.full_messages.to_sentence,
                 e.record.errors.to_hash.to_h { |attribute, messages| [ "#{prefix}#{attribute}", messages.first ] })
  end

  def process_action(*)
    super
  rescue ActionController::BadRequest
    # Rails parses the query string for its request log before any callback
    # runs, so a malformed one surfaces here, outside rescue_from. It still gets
    # an answer only with a valid token. (The body is parsed in #body_object.)
    authenticate
    render_error(400, "bad_request", "The request could not be parsed") unless performed?
  ensure
    # The audit trail: who did every write, including the refused ones.
    if @claims && !request.get? && !request.head?
      Rails.logger.info("[PushleftAdmin] write sub=#{@claims['sub'].inspect} role=#{@claims['role'].inspect} " \
                        "jti=#{@claims['jti'].inspect} #{request.request_method} #{request_target} " \
                        "status=#{performed? ? response.status : 500}")
    end
  end

  def schema
    render json: {
      protocol: 1, title: "Messy", overview: true,
      resources: RESOURCES.map do |res|
        res.slice(*RESOURCE_KEYS).merge(
          views: res[:views].map { |view| view.slice(:name, :label) },
          fields: res[:fields].map { |field| field.slice(*FIELD_KEYS) },
          actions: res[:actions].map { |action| action.slice(*ACTION_KEYS) }
        )
      end
    }
  end

  def overview
    tile = lambda do |label, resource, view = nil|
      res = RESOURCES.find { |r| r[:name] == resource }
      scope = res[:model].all
      scope = res[:views].find { |v| v[:name] == view }[:scope].call(scope) if view
      { label: label, value: scope.count, resource: resource, view: view }.compact
    end

    render json: { tiles: [
      tile.call("Workspaces", "accounts"),
      tile.call("On trial", "accounts", "on_trial"),
      tile.call("Trials ending within 7 days", "accounts", "trial_ending"),
      tile.call("Users", "users"),
      tile.call("Signed in during the last 24 hours", "users", "signed_in_24h")
    ] }
  end

  def index
    res = find_resource("list")
    scope = res[:model].all

    if (view = query_param("view"))
      found = res[:views].find { |v| v[:name] == view } or bad_request!("Unknown view")
      scope = found[:scope].call(scope)
    end
    if (q = query_param("q"))
      bad_request!("This list has no search") unless res[:search]
      scope = res[:search_scope].call(scope, "%#{ActiveRecord::Base.sanitize_sql_like(q)}%")
    end
    scope = filtered(res, scope)

    limit = query_param("limit") || "50"
    bad_request!("limit is a number from 1 to 200") unless limit.match?(/\A\d{1,4}\z/) && limit.to_i.positive?
    limit = [ limit.to_i, 200 ].min
    offset = cursor_offset(query_param("after"))

    page = sorted(res, scope).offset(offset).limit(limit + 1)
    page = page.preload(res[:preload]) if res[:preload]
    rows = page.to_a
    counts = counts_for(res, rows.first(limit).map(&:id))

    render json: {
      items: rows.first(limit).map { |record| item(res, record, counts) },
      # ponytail: the cursor is an offset. Fine for an operator paging a few
      # thousand rows; move to a keyset on (sort column, id) if deep pages get slow.
      next: rows.size > limit ? Base64.urlsafe_encode64((offset + limit).to_s, padding: false) : nil,
      # ponytail: an exact count per request. Drop `total` (it is optional) if
      # one of these tables grows past what COUNT(*) answers quickly.
      total: scope.count
    }
  end

  def show
    res = find_resource("show")
    render json: item(res, find_record(res))
  end

  # A workspace is created with its first admin, as /signup does. A user is
  # created in one workspace, as an invitation from inside it does.
  def create
    res = find_resource("create")
    values = coerce(res[:fields].select { |f| f[:create] }, body_object("values"), complete: true)

    if res[:name] == "users"
      account = Account.find_by(id: values["account"]) or
        refuse!(422, "invalid", "Some values are not valid", "account" => "is not a workspace")
      # ponytail: a new login only. Someone who already has one is invited from
      # inside the workspace, where they accept it themselves.
      user = User.create!(account: account, name: values["name"], email: values["email"].downcase,
                          role: values["role"] || "member")
      record, made = user, "User"
    else
      plan = values["plan"] || "trial"
      record = user = nil
      ActiveRecord::Base.transaction do
        record = Account.create!(name: values["name"], plan: plan,
                                 trial_ends_at: values["trial_ends_at"] || (14.days.from_now if plan == "trial"))
        user = User.create!(account: record, name: values["owner_name"],
                            email: values["owner_email"].downcase, role: :admin)
      end
      made = "Workspace"
    end
    user.generate_magic_link_token!
    UserMailer.with(user: user).verification_email.deliver_later

    render json: { item: item(res, record), message: "#{made} created. A sign-in link was mailed to #{user.email}." }
  end

  def update
    res = find_resource("update")
    record = find_record(res)
    values = coerce(res[:fields].select { |f| f[:update] }, body_object("values"), complete: false)

    if res[:name] == "memberships" && values["role"] == "member" && last_admin?(record)
      refuse!(409, "conflict", LAST_ADMIN)
    end
    # The address is the login. A person who lost their mailbox cannot move it
    # themselves, so an operator can. The steps follow the person's own change:
    # links mailed to the old address stop working, and it gets a notice.
    moved_from = nil
    if res[:name] == "users" && values["email"]
      values["email"] = values["email"].downcase
      if values["email"] != record.email
        moved_from = record.email
        values.merge!("magic_link_token" => nil, "magic_link_token_expires_at" => nil)
      end
    end
    record.update!(values)
    if moved_from
      UserMailer.with(user: record, old_email: moved_from).email_changed_notice.deliver_later
      message = "#{record.name} signs in with #{record.email} now. A notice was mailed to #{moved_from}."
    end

    render json: { item: item(res, record), message: message }.compact
  end

  def destroy
    res = find_resource("delete")
    record = find_record(res)

    case res[:name]
    when "memberships" then return render json: { message: remove_membership(record) }
    when "users"
      refuse!(409, "conflict", "The last super admin cannot be deleted") if last_super_admin?(record)
      # Their workspaces must keep someone who can administer them.
      refuse!(409, "conflict", LAST_ADMIN) if record.account_memberships.any? { |m| last_admin?(m) }
    end
    record.destroy!
    render json: { message: "#{res[:singular]} deleted" }
  end

  def run_action
    res = find_resource
    record = find_record(res)
    action = res[:actions].find { |a| a[:name] == request.path_parameters[:action_name] } or
      refuse!(404, "not_found", "Not found")
    unless action[:available].nil? || action[:available].call(record)
      refuse!(409, "conflict", "#{action[:label]} does not apply to this #{res[:singular].downcase} now")
    end
    input = coerce(action[:input] || [], body_object("input"), complete: true)

    message =
      case action[:name]
      when "extend_trial"
        unless input["until"].future?
          refuse!(422, "invalid", "The trial end must be in the future", "until" => "must be in the future")
        end
        record.update!(trial_ends_at: input["until"])
        "The trial now ends on #{input['until'].utc.to_date.to_fs(:long)}"
      when "set_plan"
        record.update!(plan: input["plan"])
        "Plan set to #{record.plan_display_name}"
      when "set_payment_status"
        record.update!(payment_status: input["payment_status"])
        label = INVOICE_STATUSES.find { |option| option[:value] == input["payment_status"] }&.fetch(:label)
        label ? "Payment status set to #{label.downcase}" : "Payment status cleared"
      when "set_super_admin"
        refuse!(409, "conflict", "The last super admin cannot be removed") if !input["super_admin"] && last_super_admin?(record)
        record.update!(is_super_admin: input["super_admin"])
        input["super_admin"] ? "#{record.email} is a super admin now" : "#{record.email} is no longer a super admin"
      when "send_sign_in_link"
        record.generate_magic_link_token!
        UserMailer.with(user: record).magic_link.deliver_later
        "A sign-in link was mailed to #{record.email}"
      end

    render json: { item: item(res, record), message: message }
  end

  def not_found
    refuse!(404, "not_found", "Not found")
  end

  private

  # ── The signed request ───────────────────────────────────────────────────────

  def authenticate
    jwks, audience = ENV["PUSHLEFT_ADMIN_JWKS"], ENV["PUSHLEFT_ADMIN_AUDIENCE"]
    return head(:not_found) if jwks.blank? || audience.blank?

    @claims = verified_claims(jwks, audience)
    render_error(401, "unauthorized", "A valid Pushleft admin token is required") unless @claims
  end

  # The claims of the bearer token, or nil unless all of these hold:
  #   1. the header alg is ES256 (never none, never a symmetric algorithm);
  #   2. the signature verifies with the key that kid names in the key set;
  #   3. aud is this environment's audience;
  #   4. exp is not past, with at most 30 seconds of clock difference;
  #   5. method and path are this request's, compared with the raw target;
  #   6. body is the SHA-256 of the bytes received.
  # Anything unexpected in here (a malformed key set included) refuses.
  #
  # ponytail: no jti replay memory. A token already works for one method, path
  # and body for 60 seconds. Refusing a second use needs a cache that every web
  # process shares, which the default cache store is not.
  def verified_claims(jwks, audience)
    token = request.authorization.to_s[/\ABearer ([\w.-]+)\z/, 1] or return nil
    keys = JSON.parse(jwks).fetch("keys").select { |key| key["kty"] == "EC" && key["crv"] == "P-256" }
    claims, = JWT.decode(token, nil, true,
                         algorithms: [ "ES256" ], jwks: { "keys" => keys },
                         aud: audience, verify_aud: true, leeway: 30,
                         required_claims: %w[exp aud sub method path body])

    claims if claims["aud"] == audience &&
              claims["sub"].is_a?(String) && claims["sub"].present? &&
              claims["method"] == request.request_method &&
              claims["path"] == request_target &&
              claims["body"] == Digest::SHA256.hexdigest(request.raw_post.to_s)
  rescue StandardError => e
    Rails.logger.warn("[PushleftAdmin] token refused: #{e.class}")
    nil
  end

  # The request target as the client sent it. Rails' own fullpath is rebuilt
  # from the parsed path and is only the fallback for servers without REQUEST_URI.
  def request_target
    request.get_header("REQUEST_URI").presence || request.original_fullpath
  end

  # ── Lookups ──────────────────────────────────────────────────────────────────

  def find_resource(operation = nil)
    res = RESOURCES.find { |r| r[:name] == request.path_parameters[:resource] }
    refuse!(404, "not_found", "Not found") unless res && (operation.nil? || res[:can].include?(operation))
    res
  end

  def find_record(res)
    id = request.path_parameters[:id].to_s
    refuse!(404, "not_found", "Not found") unless id.match?(/\A\d{1,18}\z/)
    res[:model].find(id)
  end

  def counts_for(res, ids)
    res[:fields].select { |f| f[:count] }.to_h { |f| [ f[:name], f[:count].call(ids) ] }
  end

  def item(res, record, counts = counts_for(res, [ record.id ]))
    {
      id: record.id.to_s,
      values: res[:fields].to_h do |field|
        value = if field[:count] then counts[field[:name]].fetch(record.id, 0)
                elsif field[:read] then field[:read].call(record)
                else record.public_send(field[:name])
                end
        [ field[:name], value.respond_to?(:iso8601) ? value.utc.iso8601 : value ]
      end,
      actions: res[:actions].select { |a| a[:available].nil? || a[:available].call(record) }.map { |a| a[:name] }
    }
  end

  # ── Lists ────────────────────────────────────────────────────────────────────

  def query_param(name)
    value = request.query_parameters[name]
    bad_request!("#{name} takes one value") unless value.nil? || (value.is_a?(String) && !value.include?("\0"))
    value.presence
  end

  # filter[field]=a,b matches any of the values; filter[field][gte] and [lte]
  # bound dates and numbers. Field names and columns come from RESOURCES and
  # values are cast by field type, so nothing from the query string reaches SQL
  # as text.
  def filtered(res, scope)
    filters = request.query_parameters["filter"]
    return scope if filters.nil?
    bad_request!("Filters are given as filter[field]=value") unless filters.is_a?(Hash)

    filters.each do |name, raw|
      field = res[:fields].find { |f| f[:name] == name && f[:filter] }
      unless field
        allowed = res[:fields].select { |f| f[:filter] }.map { |f| f[:name] }.join(", ")
        bad_request!("This list filters on: #{allowed}")
      end
      column = field[:column] || field[:name]

      if raw.is_a?(Hash)
        unless %w[datetime integer].include?(field[:type]) && (raw.keys - %w[gte lte]).empty?
          bad_request!("#{field[:name]}: only dates and numbers take gte and lte")
        end
        scope = scope.where(column => cast(field, raw["gte"])..) if raw.key?("gte")
        scope = scope.where(column => ..cast(field, raw["lte"])) if raw.key?("lte")
      else
        values = raw.is_a?(String) ? raw.split(",").map { |value| cast(field, value) } : []
        bad_request!("#{field[:name]}: give one or more values, separated by commas") if values.empty?
        scope = field[:where] ? field[:where].call(scope, values) : scope.where(column => values)
      end
    end
    scope
  end

  # A filter value from the query string, as the type of its field.
  def cast(field, raw)
    value =
      if !raw.is_a?(String) || raw.include?("\0") then nil
      else
        case field[:type]
        when "enum"           then raw if field[:options].any? { |option| option[:value] == raw }
        when "boolean"        then { "true" => true, "false" => false }[raw]
        when "integer", "ref" then raw.to_i if raw.match?(/\A-?\d{1,18}\z/)
        when "datetime"       then parse_time(raw)
        else raw
        end
      end
    bad_request!("#{field[:name]}: not a valid #{field[:type]} value") if value.nil?
    value
  end

  def sorted(res, scope)
    sort = query_param("sort") || res[:default_sort]
    field = res[:fields].find { |f| f[:name] == sort.delete_prefix("-") && f[:sort] }
    unless field
      allowed = res[:fields].select { |f| f[:sort] }.map { |f| f[:name] }.join(", ")
      bad_request!("This list sorts on: #{allowed}")
    end

    table = res[:model].arel_table
    if sort.start_with?("-")
      scope.order(table[field[:name]].desc.nulls_last, table[:id].desc)
    else
      scope.order(table[field[:name]].asc, table[:id].asc)
    end
  end

  def cursor_offset(cursor)
    return 0 unless cursor
    offset = Base64.urlsafe_decode64(cursor)
    raise ArgumentError unless offset.match?(/\A\d{1,9}\z/)
    offset.to_i
  rescue ArgumentError
    bad_request!("after is not a cursor from this list")
  end

  # ── Writes ───────────────────────────────────────────────────────────────────

  # The object under `key` in the JSON body. Parsed here from the bytes that the
  # token's body hash covers, not from Rails' params.
  def body_object(key)
    raw = request.raw_post
    body = raw.blank? ? {} : JSON.parse(raw)
    object = body.is_a?(Hash) ? body.fetch(key, {}) : nil
    bad_request!(%(The body is a JSON object with "#{key}")) unless object.is_a?(Hash)
    object
  rescue JSON::ParserError
    bad_request!("The body is not valid JSON")
  end

  # Checks written values (create, update, action input) against their field
  # definitions and returns them typed. Refuses with one message per field.
  # `complete` also demands every required field, as a create and an action do.
  def coerce(fields, given, complete:)
    errors = (given.keys - fields.map { |f| f[:name] }).to_h { |name| [ name, "cannot be set here" ] }
    values = {}

    fields.each do |field|
      name = field[:name]
      unless given.key?(name)
        errors[name] = "is required" if complete && field[:required]
        next
      end

      value = given[name]
      value = value.strip if value.is_a?(String)
      if value.nil? || value == ""
        # A boolean column has no "unknown".
        if field[:required] || field[:type] == "boolean"
          errors[name] = "is required"
        else
          values[name] = nil
        end
      elsif (problem = problem_with(field, value))
        errors[name] = problem
      else
        values[name] = field[:type] == "datetime" ? parse_time(value) : value
      end
    end

    refuse!(422, "invalid", "Some values are not valid", errors) if errors.any?
    values
  end

  def problem_with(field, value)
    case field[:type]
    when "boolean"
      "must be true or false" unless value == true || value == false
    when "integer"
      if !value.is_a?(Integer) then "must be a whole number"
      elsif value < field[:min] || value > field[:max] then "must be from #{field[:min]} to #{field[:max]}"
      end
    when "enum"
      "is not one of the options" unless field[:options].any? { |option| option[:value] == value }
    when "datetime"
      "must be a time such as 2026-01-31T09:00:00Z" unless parse_time(value)
    when "ref"
      "must be the id of a record" unless value.is_a?(String) && value.match?(/\A\d{1,18}\z/)
    else
      if !value.is_a?(String) || value.include?("\0") then "must be text"
      elsif field[:max_length] && value.length > field[:max_length] then "is too long (at most #{field[:max_length]} characters)"
      end
    end
  end

  # RFC 3339 only, within the years a timestamp column holds.
  def parse_time(value)
    time = Time.iso8601(value) if value.is_a?(String)
    time if time && time.year.between?(1970, 9999)
  rescue ArgumentError
    nil
  end

  def last_super_admin?(user)
    user.is_super_admin? && User.super_admins.where.not(id: user.id).none?
  end

  # True when this membership is the only accepted admin access to its
  # workspace (an admin role, or a platform super admin), so that removing or
  # demoting it would leave nobody to administer the workspace.
  def last_admin?(membership)
    return false unless membership.accepted? && (membership.admin? || membership.user.is_super_admin?)

    !AccountMembership.accepted.joins(:user)
                      .where(account_id: membership.account_id)
                      .where.not(id: membership.id)
                      .where("account_memberships.role = :admin OR users.is_super_admin = :yes",
                             admin: AccountMembership.roles[:admin], yes: true)
                      .exists?
  end

  # A person keeps their login while they have another workspace. Every user
  # row needs a default workspace, so removing the last membership removes the
  # login as well. Returns the line to show.
  def remove_membership(membership)
    refuse!(409, "conflict", LAST_ADMIN) if last_admin?(membership)

    user = membership.user
    others = user.account_memberships.where.not(id: membership.id)
    unless others.exists?
      user.destroy!
      return "#{user.email} had no other workspace, so the login was deleted too"
    end

    ActiveRecord::Base.transaction do
      membership.destroy!
      if user.account_id == membership.account_id
        # Their default workspace pointed here. Prefer one they have accepted.
        user.update_column(:account_id, others.accepted.order(:created_at).pick(:account_id) ||
                                        others.order(:created_at).pick(:account_id))
      end
    end
    "#{user.email} was removed from #{membership.account.name}"
  end

  # ── Errors ───────────────────────────────────────────────────────────────────

  def refuse!(status, code, message, fields = nil)
    raise Refusal.new(status, code, message, fields)
  end

  def bad_request!(message)
    refuse!(400, "bad_request", message)
  end

  def render_error(status, code, message, fields = nil)
    render json: { error: { code: code, message: message, fields: fields }.compact }, status: status
  end
end
