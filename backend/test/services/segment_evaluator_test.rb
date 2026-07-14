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
end
