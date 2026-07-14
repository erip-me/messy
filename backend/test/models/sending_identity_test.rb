require "test_helper"

class SendingIdentityTest < ActiveSupport::TestCase
  setup { @account = accounts(:acme) }

  test "requires a valid email" do
    assert_not @account.sending_identities.new(from_email: "").valid?
    assert_not @account.sending_identities.new(from_email: "not-an-email").valid?
    assert @account.sending_identities.new(from_email: "peter@lalaaji.com").valid?
  end

  test "formatted_from includes the display name when present" do
    assert_equal "Peter <peter@lalaaji.com>",
                 @account.sending_identities.new(from_name: "Peter", from_email: "peter@lalaaji.com").formatted_from
    assert_equal "peter@lalaaji.com",
                 @account.sending_identities.new(from_email: "peter@lalaaji.com").formatted_from
  end

  test "from_line prefers the explicit identity" do
    explicit = @account.sending_identities.create!(from_name: "Peter", from_email: "peter@lalaaji.com")
    @account.sending_identities.create!(from_email: "default@lalaaji.com", is_default: true)

    assert_equal "Peter <peter@lalaaji.com>", SendingIdentity.from_line(explicit, @account)
  end

  test "from_line falls back to the account default, then nil" do
    assert_nil SendingIdentity.from_line(nil, @account)

    @account.sending_identities.create!(from_email: "default@lalaaji.com", is_default: true)
    assert_equal "default@lalaaji.com", SendingIdentity.from_line(nil, @account.reload)
  end
end
