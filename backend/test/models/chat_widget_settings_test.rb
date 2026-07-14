require "test_helper"

class ChatWidgetSettingsTest < ActiveSupport::TestCase
  test "validates account uniqueness" do
    duplicate = ChatWidgetSettings.new(account: accounts(:acme))
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:account_id], "has already been taken"
  end

  test "validates position values" do
    settings = chat_widget_settings(:acme_settings)
    settings.position = "bottom-right"
    assert settings.valid?

    settings.position = "bottom-left"
    assert settings.valid?

    settings.position = "top-right"
    assert_not settings.valid?
  end

  test "validates color format" do
    settings = chat_widget_settings(:acme_settings)

    settings.primary_color = "#3B86E4"
    assert settings.valid?

    settings.primary_color = "not-a-color"
    assert_not settings.valid?

    settings.primary_color = "#GGG"
    assert_not settings.valid?
  end

  test "validates auto_close_hours positive" do
    settings = chat_widget_settings(:acme_settings)
    settings.auto_close_hours = 0
    assert_not settings.valid?

    settings.auto_close_hours = 48
    assert settings.valid?
  end

  test "default values are set" do
    settings = ChatWidgetSettings.new(account: accounts(:other_co))
    assert settings.enabled
    assert_equal "bottom-right", settings.position
    assert settings.show_operator_avatars
    assert settings.show_operator_count
    assert_not settings.business_hours_enabled
    assert_equal 24, settings.auto_close_hours
  end

  test "within_business_hours? returns true when disabled" do
    settings = chat_widget_settings(:acme_settings)
    settings.business_hours_enabled = false
    assert settings.within_business_hours?
  end

  test "as_widget_json returns expected keys" do
    settings = chat_widget_settings(:acme_settings)
    json = settings.as_widget_json
    assert_equal "#3B86E4", json[:primary_color]
    assert_equal "bottom-right", json[:position]
    assert_equal "Hi there! How can we help?", json[:greeting_message]
  end
end
