require "test_helper"

class DeviceTokenPushTest < ActiveSupport::TestCase
  test "for_platform scope filters by platform" do
    ios_tokens = DeviceToken.for_platform(:ios)
    assert_includes ios_tokens, device_tokens(:johns_iphone)
    assert_not_includes ios_tokens, device_tokens(:johns_android)
    assert_not_includes ios_tokens, device_tokens(:johns_web)

    android_tokens = DeviceToken.for_platform(:android)
    assert_includes android_tokens, device_tokens(:johns_android)
    assert_not_includes android_tokens, device_tokens(:johns_iphone)

    web_tokens = DeviceToken.for_platform(:web)
    assert_includes web_tokens, device_tokens(:johns_web)
    assert_not_includes web_tokens, device_tokens(:johns_iphone)
  end

  test "for_platform accepts array of platforms" do
    tokens = DeviceToken.for_platform([:android, :ios])
    assert_includes tokens, device_tokens(:johns_iphone)
    assert_includes tokens, device_tokens(:johns_android)
    assert_not_includes tokens, device_tokens(:johns_web)
  end

  test "for_app scope filters by app_id" do
    dt = device_tokens(:johns_iphone)
    dt.update!(app_id: "com.example.app")

    results = DeviceToken.for_app("com.example.app")
    assert_includes results, dt
    assert_not_includes results, device_tokens(:johns_android)
  end

  test "touch_last_used! updates last_used_at" do
    dt = device_tokens(:johns_iphone)
    assert_nil dt.last_used_at

    dt.touch_last_used!
    assert_not_nil dt.reload.last_used_at
  end

  test "web platform enum value" do
    assert device_tokens(:johns_web).web?
  end
end
