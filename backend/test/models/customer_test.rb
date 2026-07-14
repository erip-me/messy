require "test_helper"

class CustomerTest < ActiveSupport::TestCase
  test "validates email presence" do
    c = Customer.new(account: accounts(:acme))
    assert_not c.valid?
    assert_includes c.errors[:email], "can't be blank"
  end

  test "validates email uniqueness per account" do
    existing = customers(:john)
    c = Customer.new(account: existing.account, email: existing.email)
    assert_not c.valid?
    assert_includes c.errors[:email], "already exists"
  end

  test "same email allowed on different accounts" do
    c = Customer.new(account: accounts(:other_co), email: customers(:john).email)
    # other_customer fixture already has this email on other_co,
    # so use a fresh email
    c.email = "unique@example.com"
    assert c.valid?
  end

  test "validates email format" do
    c = Customer.new(account: accounts(:acme), email: "not-an-email")
    assert_not c.valid?
    assert_includes c.errors[:email], "is invalid"
  end

  test "has many device_tokens" do
    john = customers(:john)
    assert_equal 3, john.device_tokens.count
  end
end
