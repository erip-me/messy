require "test_helper"

class SegmentEvaluatorTest < ActiveSupport::TestCase
  test "evaluate returns only customers within the base scope" do
    acme_scope = accounts(:acme).customers
    conditions = {
      "operator" => "and",
      "conditions" => [
        { "attribute" => "email", "operator" => "contains", "value" => "@example.com" }
      ]
    }

    results = SegmentEvaluator.new(acme_scope, conditions).evaluate
    result_ids = results.pluck(:id)

    # Both acme customers match, but other_co's customer must not appear
    assert_includes result_ids, customers(:john).id
    assert_includes result_ids, customers(:jane).id
    assert_not_includes result_ids, customers(:other_customer).id
  end

  test "evaluate with other_co scope never returns acme customers" do
    other_scope = accounts(:other_co).customers
    conditions = {
      "operator" => "and",
      "conditions" => [
        { "attribute" => "email", "operator" => "contains", "value" => "@example.com" }
      ]
    }

    results = SegmentEvaluator.new(other_scope, conditions).evaluate
    result_ids = results.pluck(:id)

    assert_includes result_ids, customers(:other_customer).id
    assert_not_includes result_ids, customers(:john).id
    assert_not_includes result_ids, customers(:jane).id
  end

  test "evaluate with empty conditions returns full base scope unchanged" do
    acme_scope = accounts(:acme).customers
    results = SegmentEvaluator.new(acme_scope, {}).evaluate

    assert_equal acme_scope.count, results.count
    assert_not_includes results.pluck(:id), customers(:other_customer).id
  end

  test "count respects base scope boundary" do
    acme_scope = accounts(:acme).customers
    other_scope = accounts(:other_co).customers
    conditions = {
      "operator" => "and",
      "conditions" => [
        { "attribute" => "email", "operator" => "contains", "value" => "john" }
      ]
    }

    # john@example.com exists in both accounts
    acme_count = SegmentEvaluator.new(acme_scope, conditions).count
    other_count = SegmentEvaluator.new(other_scope, conditions).count

    assert_equal 1, acme_count
    assert_equal 1, other_count
  end

  test "custom attribute condition stays within base scope" do
    acme_scope = accounts(:acme).customers
    conditions = {
      "operator" => "and",
      "conditions" => [
        { "attribute" => "custom.role", "operator" => "equals", "value" => "buyer" }
      ]
    }

    results = SegmentEvaluator.new(acme_scope, conditions).evaluate
    result_ids = results.pluck(:id)

    assert_includes result_ids, customers(:john).id
    assert_equal 1, results.count
    assert_not_includes result_ids, customers(:other_customer).id
  end

  test "or-group conditions stay within base scope" do
    acme_scope = accounts(:acme).customers
    conditions = {
      "operator" => "or",
      "conditions" => [
        { "attribute" => "first_name", "operator" => "equals", "value" => "John" },
        { "attribute" => "first_name", "operator" => "equals", "value" => "Jane" }
      ]
    }

    results = SegmentEvaluator.new(acme_scope, conditions).evaluate
    result_ids = results.pluck(:id)

    assert_equal 2, results.count
    assert_not_includes result_ids, customers(:other_customer).id
  end

  test "segment model evaluate method scopes to given account" do
    segment = segments(:active_buyers)
    results = segment.evaluate(accounts(:acme))
    result_ids = results.pluck(:id)

    assert_includes result_ids, customers(:john).id
    assert_not_includes result_ids, customers(:other_customer).id
  end

  test "rolling day operators match custom timestamps against now" do
    scope = accounts(:acme).customers
    customers(:john).update!(custom_attributes: { "last_seen_at" => 200.days.ago.iso8601 })
    customers(:jane).update!(custom_attributes: { "last_seen_at" => 10.days.ago.iso8601 })
    run = ->(op, v) { SegmentEvaluator.new(scope, { "conditions" => [{ "attribute" => "custom.last_seen_at", "operator" => op, "value" => v }] }).evaluate.pluck(:id) }

    assert_equal [customers(:john).id], run.("more_than_days_ago", "180")
    assert_equal [customers(:jane).id], run.("less_than_days_ago", "180")
    customers(:john).update!(custom_attributes: { "last_seen_at" => 5.days.from_now.iso8601 })
    assert_equal [customers(:jane).id], run.("less_than_days_ago", "180"), "future dates are not within the last N days"
    customers(:john).update!(custom_attributes: { "last_seen_at" => 200.days.ago.iso8601 })
    # A bad day count matches no one: dropping it would make the segment match everyone.
    assert_empty run.("more_than_days_ago", "1; DROP TABLE customers")
    assert_empty run.("more_than_days_ago", "")
    assert_empty run.("more_than_days_ago", "-5")
    assert_empty run.("more_than_days_ago", "99999999999")
    assert_empty run.("on", "")
    assert_empty run.("before", "not-a-date")
    assert_empty run.("after", "0000-01-01")
    assert_empty run.("on", "-0001-01-01")

    # A non-date value on the same key is skipped, not a query-wide cast error.
    customers(:jane).update!(custom_attributes: { "last_seen_at" => "never" })
    assert_equal [customers(:john).id], run.("more_than_days_ago", "180")

    # Dates that look right but don't exist are skipped too.
    %w[2026-99-99 2026-02-30 0000-01-01 2026-01-01Tjunk 2026-01-01T10:00:00+99:00].each do |bad|
      customers(:jane).update!(custom_attributes: { "last_seen_at" => bad })
      assert_equal [customers(:john).id], run.("more_than_days_ago", "180"), bad
    end

    # "on" compares the calendar date of an ISO timestamp; legacy "equals" on a date reads the same.
    assert_equal [customers(:john).id], run.("equals", 200.days.ago.to_date.iso8601)

    # Calendar rules use the day as written, not one shifted into the database timezone.
    customers(:jane).update!(custom_attributes: { "last_seen_at" => "2026-01-01T23:30:00-05:00" })
    assert_equal [customers(:jane).id], run.("on", "2026-01-01")
    assert_equal [customers(:john).id], run.("on", 200.days.ago.to_date.iso8601)
  end

  test "nested groups are applied, not dropped" do
    scope = accounts(:acme).customers
    customers(:john).update!(custom_attributes: { "role" => "seller", "last_seen_at" => 200.days.ago.iso8601 })
    customers(:jane).update!(custom_attributes: { "role" => "seller", "last_seen_at" => 10.days.ago.iso8601 })
    conditions = {
      "operator" => "and",
      "conditions" => [
        { "attribute" => "custom.role", "operator" => "equals", "value" => "seller" },
        { "operator" => "or", "conditions" => [
          { "attribute" => "custom.last_seen_at", "operator" => "more_than_days_ago", "value" => "180" },
          { "attribute" => "custom.last_seen_at", "operator" => "is_blank", "value" => "" }
        ] }
      ]
    }

    assert_equal [customers(:john).id], SegmentEvaluator.new(scope, conditions).evaluate.pluck(:id)
  end
end
