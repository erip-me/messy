require "test_helper"

class DeviceTokenTest < ActiveSupport::TestCase
  test "validates token presence" do
    dt = DeviceToken.new(account: accounts(:acme), customer: customers(:john), platform: :ios)
    assert_not dt.valid?
    assert_includes dt.errors[:token], "can't be blank"
  end

  test "validates token uniqueness" do
    existing = device_tokens(:johns_iphone)
    dt = DeviceToken.new(
      account: accounts(:acme),
      customer: customers(:jane),
      token: existing.token,
      platform: :ios
    )
    assert_not dt.valid?
    assert_includes dt.errors[:token], "has already been taken"
  end

  test "active scope excludes inactive tokens" do
    active = DeviceToken.active
    assert_includes active, device_tokens(:johns_iphone)
    assert_includes active, device_tokens(:johns_android)
    assert_not_includes active, device_tokens(:inactive_token)
  end

  test "deactivate! sets active to false" do
    dt = device_tokens(:johns_iphone)
    assert dt.active
    dt.deactivate!
    assert_not dt.reload.active
  end

  test "platform enum" do
    assert device_tokens(:johns_iphone).ios?
    assert device_tokens(:johns_android).android?
  end
end
