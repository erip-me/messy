require "test_helper"

class EnvironmentTest < ActiveSupport::TestCase
  fixtures :all

  test "validates name presence" do
    env = Environment.new(account: accounts(:acme), name: nil)
    assert_not env.valid?
    assert_includes env.errors[:name], "can't be blank"
  end

  test "auto-generates api_key on create" do
    env = Environment.new(account: accounts(:acme), name: "Test Env")
    env.valid?
    assert_not_nil env.api_key
    assert env.api_key.end_with?("==")
  end

  test "does not overwrite existing api_key on create" do
    env = Environment.new(account: accounts(:acme), name: "Test Env", api_key: "custom_key==")
    env.valid?
    assert_equal "custom_key==", env.api_key
  end

  test "active scope excludes deleted environments" do
    env = environments(:production)
    env.update_column(:is_deleted, true)

    active = Environment.active
    assert_not_includes active, env
    assert_includes active, environments(:staging)
  end

  test "check_rules? returns :passed when rule allows" do
    env = environments(:production)
    message = messages(:email_one)
    rcpt = "domain == 'acme.com'"

    result = env.check_rules?(message, rcpt)
    assert_equal :passed, result
  end

  test "check_rules? returns :failed when rule denies" do
    env = environments(:production)
    message = messages(:email_one)
    rcpt = "domain != 'acme.com'"

    result = env.check_rules?(message, rcpt)
    assert_equal :failed, result
  end

  test "check_rules? falls back to global channel permission when no rules match" do
    env = environments(:production)
    # Remove all rules so none match
    env.rules.destroy_all

    message = messages(:email_one)
    rcpt = "no-match@example.com"

    # allow_email is true for production
    result = env.check_rules?(message, rcpt)
    assert_equal :passed, result
  end

  test "check_rules? falls back to denied when global channel permission is false" do
    env = environments(:staging)
    env.rules.destroy_all

    message = messages(:sms_one)
    rcpt = "no-match"

    # allow_sms is false for staging
    result = env.check_rules?(message, rcpt)
    assert_equal :failed, result
  end

  # --- Environment isolation tests ---

  test "check_rules? only evaluates rules belonging to that environment" do
    prod = environments(:production)
    staging = environments(:staging)
    message = messages(:email_one)

    # "tuli.com" is denied in staging (staging_deny rule) but has no matching
    # rule in production — production falls back to allow_email: true
    prod_result = prod.check_rules?(message, "user@tuli.com")
    staging_result = staging.check_rules?(message, "user@tuli.com")

    assert_equal :passed, prod_result, "Production should pass (no matching rule, fallback allow_email)"
    assert_equal :failed, staging_result, "Staging should deny tuli.com via its own rule"
  end

  test "check_rules? does not leak staging rules into production" do
    prod = environments(:production)
    message = messages(:email_one)

    # "mailinator.com" is explicitly allowed in staging, but production has no
    # rule for it — should fall back to global allow_email (true)
    result = prod.check_rules?(message, "user@mailinator.com")
    assert_equal :passed, result, "Production should not see staging's allow rule"

    # Verify production has no rule with this condition
    assert_empty prod.rules.where("condition LIKE ?", "%mailinator%"),
      "Production should have no mailinator rules"
  end

  test "staging allow rule does not affect production" do
    prod = environments(:production)
    staging = environments(:staging)
    message = messages(:email_one)

    # mailinator.com is explicitly allowed in staging
    staging_result = staging.check_rules?(message, "user@mailinator.com")
    assert_equal :passed, staging_result

    # But in production, there's no mailinator rule — verify the allow
    # came from fallback, not from staging's rule leaking over
    prod.update!(allow_email: false)
    prod_result = prod.check_rules?(message, "user@mailinator.com")
    assert_equal :failed, prod_result,
      "With allow_email off and no matching rule, production should deny"
  end

  test "environments have completely separate rule sets" do
    prod = environments(:production)
    staging = environments(:staging)

    prod_rule_ids = prod.rules.pluck(:id)
    staging_rule_ids = staging.rules.pluck(:id)

    assert_not_empty prod_rule_ids, "Production should have rules"
    assert_not_empty staging_rule_ids, "Staging should have rules"
    assert_empty prod_rule_ids & staging_rule_ids, "No rules should be shared between environments"
  end

  # --- Active filtering tests ---

  test "check_rules? ignores inactive rules" do
    prod = environments(:production)
    message = messages(:email_one)

    # inactive_deny_all has condition "@" with outcome deny — would match any
    # email. But it's inactive so should be skipped, falling back to allow_email.
    result = prod.check_rules?(message, "user@something-random.com")
    assert_equal :passed, result, "Inactive deny-all rule should be ignored"
  end

  test "check_rules? denies when inactive rule is activated" do
    prod = environments(:production)
    message = messages(:email_one)

    # Activate the deny-all rule
    rules(:inactive_deny_all).update!(active: true)

    result = prod.check_rules?(message, "user@something-random.com")
    assert_equal :failed, result, "Once activated, deny-all rule should block delivery"
  end

  test "check_rules? falls back to global permission when all rules deactivated" do
    prod = environments(:production)
    message = messages(:email_one)

    prod.rules.update_all(active: false)

    result = prod.check_rules?(message, "user@anything.com")
    assert_equal :passed, result, "Should fall back to global allow_email when no active rules"
  end

  # --- Integration preference tests ---

  test "resolve_integration returns notification preference for system emails" do
    env = environments(:production)
    ses = integrations(:ses)
    env.update_columns(notification_email_integration_id: ses.id)

    result = env.resolve_integration(:email, purpose: :notification)
    assert_equal ses, result
  end

  test "resolve_integration returns campaign preference for campaign emails" do
    env = environments(:production)
    ses = integrations(:ses)

    smtp = Integration.create!(
      account: accounts(:acme), environment: env,
      kind: :email, type: "SmtpIntegration", vendor: "smtp",
      config: { smtp_server: "smtp.example.com", port: 587, username: "user", password: "pass", from: "camp@example.com" }
    )
    env.update_columns(notification_email_integration_id: ses.id, campaign_email_integration_id: smtp.id)

    notification_result = env.resolve_integration(:email, purpose: :notification)
    campaign_result = env.resolve_integration(:email, purpose: :campaign)

    assert_equal ses, notification_result
    assert_equal smtp, campaign_result

    smtp.destroy!
  end

  test "resolve_integration campaign falls back to notification when no campaign preference" do
    env = environments(:production)
    ses = integrations(:ses)
    env.update_columns(notification_email_integration_id: ses.id, campaign_email_integration_id: nil)

    result = env.resolve_integration(:email, purpose: :campaign)
    assert_equal ses, result
  end

  test "resolve_integration falls back to first active when no preference set" do
    env = environments(:production)
    env.update_columns(notification_email_integration_id: nil, campaign_email_integration_id: nil)

    result = env.resolve_integration(:email, purpose: :notification)
    assert_equal integrations(:ses), result, "Should fall back to first active email integration"
  end

  test "resolve_integration skips inactive preferred integration and falls back" do
    env = environments(:production)
    ses = integrations(:ses)
    ses.update_column(:active, false)
    env.update_columns(notification_email_integration_id: ses.id)

    smtp = Integration.create!(
      account: accounts(:acme), environment: env,
      kind: :email, type: "SmtpIntegration", vendor: "smtp", active: true,
      config: { smtp_server: "smtp.example.com", port: 587, username: "user", password: "pass", from: "x@example.com" }
    )

    result = env.resolve_integration(:email, purpose: :notification)
    assert_equal smtp, result, "Should fall back to first active integration when preferred is inactive"

    ses.update_column(:active, true)
    smtp.destroy!
  end

  test "resolve_integration for non-email kinds uses first active" do
    env = environments(:production)
    result = env.resolve_integration(:sms, purpose: :notification)
    assert_equal integrations(:twilio), result
  end

  test "resolve_integration falls back to account-level integration" do
    env = environments(:production)
    # Deactivate all env-level email integrations instead of destroying
    env.integrations.email.update_all(active: false)
    env.update_columns(notification_email_integration_id: nil, campaign_email_integration_id: nil)

    account_int = Integration.create!(
      account: accounts(:acme), environment: nil,
      kind: :email, type: "SmtpIntegration", vendor: "smtp", active: true,
      config: { smtp_server: "smtp.example.com", port: 587, username: "user", password: "pass", from: "x@example.com" }
    )

    result = env.resolve_integration(:email, purpose: :notification)
    assert_equal account_int, result

    account_int.destroy!
    env.integrations.email.update_all(active: true)
  end

  test "validates notification preference belongs to this environment" do
    env = environments(:production)
    other_int = integrations(:ses)
    # Point to an integration in a different environment
    other_env_int = Integration.create!(
      account: accounts(:acme), environment: environments(:staging),
      kind: :email, type: "SmtpIntegration", vendor: "smtp",
      config: {}
    )

    env.notification_email_integration_id = other_env_int.id
    assert_not env.valid?
    assert_includes env.errors[:notification_email_integration], "must be an email integration available to this environment"

    other_env_int.destroy!
  end

  test "validates campaign preference belongs to this environment" do
    env = environments(:production)
    env.campaign_email_integration_id = integrations(:twilio).id # SMS, not email
    assert_not env.valid?
    assert_includes env.errors[:campaign_email_integration], "must be an email integration available to this environment"
  end

  # ─── Default permission (allow_*) × rules matrix ───────────────────

  test "allow_email=true, no rules → allows unmatched recipients" do
    env = environments(:production)
    env.rules.destroy_all
    env.update!(allow_email: true)

    result = env.check_rules?(messages(:email_one), "stranger@example.com")
    assert_equal :passed, result
  end

  test "allow_email=false, no rules → blocks unmatched recipients" do
    env = environments(:production)
    env.rules.destroy_all
    env.update!(allow_email: false)

    result = env.check_rules?(messages(:email_one), "stranger@example.com")
    assert_equal :failed, result
  end

  test "allow_email=false, allow rule matches → allows (rule overrides default)" do
    env = environments(:production)
    env.rules.destroy_all
    env.update!(allow_email: false)

    EmailRule.create!(
      account: accounts(:acme), environment: env,
      name: "Allow VIP", condition: "vip.com", outcome: :allow, active: true
    )

    result = env.check_rules?(messages(:email_one), "boss@vip.com")
    assert_equal :passed, result
  end

  test "allow_email=true, deny rule matches → blocks (rule overrides default)" do
    env = environments(:production)
    env.rules.destroy_all
    env.update!(allow_email: true)

    EmailRule.create!(
      account: accounts(:acme), environment: env,
      name: "Block spam", condition: "spam.com", outcome: :deny, active: true
    )

    result = env.check_rules?(messages(:email_one), "user@spam.com")
    assert_equal :failed, result
  end

  test "allow_email=false, deny rule matches → still blocked" do
    env = environments(:production)
    env.rules.destroy_all
    env.update!(allow_email: false)

    EmailRule.create!(
      account: accounts(:acme), environment: env,
      name: "Block bad", condition: "bad.com", outcome: :deny, active: true
    )

    result = env.check_rules?(messages(:email_one), "user@bad.com")
    assert_equal :failed, result
  end

  test "allow_email=true, allow rule matches → still allowed" do
    env = environments(:production)
    env.rules.destroy_all
    env.update!(allow_email: true)

    EmailRule.create!(
      account: accounts(:acme), environment: env,
      name: "Allow partner", condition: "partner.com", outcome: :allow, active: true
    )

    result = env.check_rules?(messages(:email_one), "user@partner.com")
    assert_equal :passed, result
  end

  test "allow_email=false, rule does not match → falls through to block" do
    env = environments(:production)
    env.rules.destroy_all
    env.update!(allow_email: false)

    EmailRule.create!(
      account: accounts(:acme), environment: env,
      name: "Allow VIP only", condition: "vip.com", outcome: :allow, active: true
    )

    result = env.check_rules?(messages(:email_one), "nobody@random.com")
    assert_equal :failed, result, "Unmatched recipient should be blocked when allow_email is off"
  end

  test "allow_email=true, rule does not match → falls through to allow" do
    env = environments(:production)
    env.rules.destroy_all
    env.update!(allow_email: true)

    EmailRule.create!(
      account: accounts(:acme), environment: env,
      name: "Block specific", condition: "blocked.com", outcome: :deny, active: true
    )

    result = env.check_rules?(messages(:email_one), "nobody@random.com")
    assert_equal :passed, result, "Unmatched recipient should be allowed when allow_email is on"
  end

  test "allow_email=false, inactive allow rule → still blocked (inactive ignored)" do
    env = environments(:production)
    env.rules.destroy_all
    env.update!(allow_email: false)

    EmailRule.create!(
      account: accounts(:acme), environment: env,
      name: "Allow all (disabled)", condition: "@", outcome: :allow, active: false
    )

    result = env.check_rules?(messages(:email_one), "user@anything.com")
    assert_equal :failed, result, "Inactive allow-all rule should be ignored, falling to block"
  end

  test "allow_email=true, inactive deny rule → still allowed (inactive ignored)" do
    env = environments(:production)
    env.rules.destroy_all
    env.update!(allow_email: true)

    EmailRule.create!(
      account: accounts(:acme), environment: env,
      name: "Deny all (disabled)", condition: "@", outcome: :deny, active: false
    )

    result = env.check_rules?(messages(:email_one), "user@anything.com")
    assert_equal :passed, result, "Inactive deny-all rule should be ignored, falling to allow"
  end

  test "first matching rule wins — allow before deny" do
    env = environments(:production)
    env.rules.destroy_all
    env.update!(allow_email: false)

    EmailRule.create!(
      account: accounts(:acme), environment: env,
      name: "Allow example", condition: "example.com", outcome: :allow, active: true
    )
    EmailRule.create!(
      account: accounts(:acme), environment: env,
      name: "Deny example", condition: "example.com", outcome: :deny, active: true
    )

    result = env.check_rules?(messages(:email_one), "user@example.com")
    assert_equal :passed, result, "First matching rule (allow) should win"
  end

  test "first matching rule wins — deny before allow" do
    env = environments(:production)
    env.rules.destroy_all
    env.update!(allow_email: true)

    EmailRule.create!(
      account: accounts(:acme), environment: env,
      name: "Deny example", condition: "example.com", outcome: :deny, active: true
    )
    EmailRule.create!(
      account: accounts(:acme), environment: env,
      name: "Allow example", condition: "example.com", outcome: :allow, active: true
    )

    result = env.check_rules?(messages(:email_one), "user@example.com")
    assert_equal :failed, result, "First matching rule (deny) should win"
  end

  # ─── SMS channel default permission ────────────────────────────────

  test "allow_sms=true, no rules → allows SMS" do
    env = environments(:production)
    env.rules.destroy_all
    env.update!(allow_sms: true)

    result = env.check_rules?(messages(:sms_one), "+15551234567")
    assert_equal :passed, result
  end

  test "allow_sms=false, no rules → blocks SMS" do
    env = environments(:production)
    env.rules.destroy_all
    env.update!(allow_sms: false)

    result = env.check_rules?(messages(:sms_one), "+15551234567")
    assert_equal :failed, result
  end

  test "allow_sms=false, matching allow rule → allows SMS" do
    env = environments(:production)
    env.rules.destroy_all
    env.update!(allow_sms: false)

    SmsRule.create!(
      account: accounts(:acme), environment: env,
      name: "Allow US numbers", condition: "+1555", outcome: :allow, active: true
    )

    result = env.check_rules?(messages(:sms_one), "+15551234567")
    assert_equal :passed, result
  end

  # ─── Channel scoping ───────────────────────────────────────────────

  test "check_rules? only evaluates rules belonging to the message's channel" do
    env = environments(:production)
    env.rules.destroy_all
    env.update!(allow_email: true, allow_sms: true)

    SmsRule.create!(
      account: accounts(:acme), environment: env,
      name: "Block acme over SMS", condition: "acme.com", outcome: :deny, active: true
    )

    # An SMS rule must not block an email to a recipient it happens to match.
    assert_equal :passed, env.check_rules?(messages(:email_one), "user@acme.com")

    # ...but it still applies to its own channel.
    assert_equal :failed, env.check_rules?(messages(:sms_one), "user@acme.com")
  end

  test "check_rules? applies channel scoping to preloaded_rules too" do
    env = environments(:production)
    env.rules.destroy_all
    env.update!(allow_email: true)

    SmsRule.create!(
      account: accounts(:acme), environment: env,
      name: "Block acme over SMS", condition: "acme.com", outcome: :deny, active: true
    )
    preloaded = env.rules.where(active: true).to_a

    check = env.check_rules_for_channel?("email", "user@acme.com", preloaded_rules: preloaded)
    assert_equal :passed, check[:result]
  end
end
