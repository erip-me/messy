require "test_helper"

class CannedResponseTest < ActiveSupport::TestCase
  test "validates shortcut presence" do
    cr = CannedResponse.new(account: accounts(:acme), title: "T", content: "C")
    assert_not cr.valid?
    assert_includes cr.errors[:shortcut], "can't be blank"
  end

  test "validates title presence" do
    cr = CannedResponse.new(account: accounts(:acme), shortcut: "/x", content: "C")
    assert_not cr.valid?
    assert_includes cr.errors[:title], "can't be blank"
  end

  test "validates content presence" do
    cr = CannedResponse.new(account: accounts(:acme), shortcut: "/x", title: "T")
    assert_not cr.valid?
    assert_includes cr.errors[:content], "can't be blank"
  end

  test "validates shortcut uniqueness per account" do
    existing = canned_responses(:greeting)
    duplicate = CannedResponse.new(
      account: existing.account,
      shortcut: existing.shortcut,
      title: "Dup",
      content: "Dup"
    )
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:shortcut], "has already been taken"
  end

  test "search scope finds by shortcut" do
    results = CannedResponse.where(account: accounts(:acme)).search("greeting")
    assert_includes results, canned_responses(:greeting)
  end

  test "search scope finds by title" do
    results = CannedResponse.where(account: accounts(:acme)).search("pricing")
    assert_includes results, canned_responses(:pricing)
  end

  test "search scope finds by content" do
    results = CannedResponse.where(account: accounts(:acme)).search("reaching out")
    assert_includes results, canned_responses(:greeting)
  end

  test "belongs to created_by user" do
    cr = canned_responses(:greeting)
    assert_equal users(:admin), cr.created_by
  end
end
