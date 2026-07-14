require "test_helper"

class AccountTest < ActiveSupport::TestCase
  fixtures :all

  test "validates name presence" do
    account = Account.new(name: nil, plan: "trial")
    assert_not account.valid?
    assert_includes account.errors[:name], "can't be blank"
  end

  test "trial? returns true for trial plan" do
    account = accounts(:acme)
    assert account.trial?
  end

  test "trial? returns false for non-trial plan" do
    account = accounts(:acme)
    account.plan = "pro"
    assert_not account.trial?
  end

  test "trial_expired? returns true when trial_ends_at is past" do
    account = accounts(:acme)
    account.trial_ends_at = 1.day.ago
    assert account.trial_expired?
  end

  test "trial_expired? returns false when trial_ends_at is future" do
    account = accounts(:acme)
    account.trial_ends_at = 30.days.from_now
    assert_not account.trial_expired?
  end

  test "has_many users" do
    account = accounts(:acme)
    assert_includes account.users, users(:admin)
    assert_includes account.users, users(:regular)
  end

  test "has_many environments" do
    account = accounts(:acme)
    assert_includes account.environments, environments(:production)
    assert_includes account.environments, environments(:staging)
  end

  test "has_many messages" do
    account = accounts(:acme)
    assert_includes account.messages, messages(:email_one)
  end

  test "has_many integrations" do
    account = accounts(:acme)
    assert_includes account.integrations, integrations(:ses)
    assert_includes account.integrations, integrations(:twilio)
  end

  test "has_many templates" do
    account = accounts(:acme)
    assert_includes account.templates, templates(:welcome)
  end

  test "has_many rules" do
    account = accounts(:acme)
    assert_includes account.rules, rules(:allow_internal)
  end

  test "has_many folders" do
    account = accounts(:acme)
    assert_includes account.folders, folders(:root_folder)
  end

  # ── Message retention validation ────────────────────────────────────────────

  test "allows 30-day message retention" do
    account = accounts(:acme)
    account.message_retention_days = 30
    assert account.valid?
  end

  test "allows 60-day message retention" do
    account = accounts(:acme)
    account.message_retention_days = 60
    assert account.valid?
  end

  test "allows 90-day message retention" do
    account = accounts(:acme)
    account.message_retention_days = 90
    assert account.valid?
  end

  test "allows 180-day message retention" do
    account = accounts(:acme)
    account.message_retention_days = 180
    assert account.valid?
  end

  test "defaults to 180-day message retention" do
    account = Account.new(name: "Test", plan: "trial", status: "active")
    assert_equal 180, account.message_retention_days
  end

  test "rejects nil message_retention_days" do
    account = accounts(:acme)
    account.message_retention_days = nil
    assert_not account.valid?
    assert_includes account.errors[:message_retention_days], "is not included in the list"
  end

  test "rejects invalid message_retention_days values" do
    account = accounts(:acme)

    [1, 7, 14, 15, 29, 31, 45, 59, 61, 89, 91, 120, 365, -1, 0].each do |invalid|
      account.message_retention_days = invalid
      assert_not account.valid?, "#{invalid} should not be a valid retention period"
      assert_includes account.errors[:message_retention_days], "is not included in the list"
    end
  end
end
