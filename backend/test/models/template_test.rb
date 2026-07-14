require "test_helper"

class TemplateTest < ActiveSupport::TestCase
  fixtures :all

  test "validates name presence" do
    template = templates(:welcome)
    template.name = nil
    assert_not template.valid?
    assert_includes template.errors[:name], "can't be blank"
  end

  test "validates trigger presence" do
    template = templates(:welcome)
    template.trigger = nil
    assert_not template.valid?
    assert_includes template.errors[:trigger], "can't be blank"
  end

  test "validates body presence" do
    template = templates(:welcome)
    template.body = nil
    assert_not template.valid?
    assert_includes template.errors[:body], "can't be blank"
  end

  test "validates channel presence" do
    template = templates(:welcome)
    template.channel = nil
    assert_not template.valid?
    assert_includes template.errors[:channel], "can't be blank"
  end

  test "validates channel inclusion" do
    template = templates(:welcome)
    template.channel = "fax"
    assert_not template.valid?
    assert_includes template.errors[:channel], "is not included in the list"
  end

  test "validates body_format presence" do
    template = templates(:welcome)
    template.body_format = nil
    assert_not template.valid?
    assert_includes template.errors[:body_format], "can't be blank"
  end

  test "validates body_format inclusion" do
    template = templates(:welcome)
    template.body_format = "rtf"
    assert_not template.valid?
    assert_includes template.errors[:body_format], "is not included in the list"
  end

  test "allows html body_format" do
    template = templates(:welcome)
    template.body_format = "html"
    assert template.valid?
  end

  test "allows markdown body_format" do
    template = templates(:welcome)
    template.body_format = "markdown"
    assert template.valid?
  end

  test "validates trigger uniqueness per environment and channel" do
    existing = templates(:welcome)
    duplicate = Template.new(
      account: existing.account,
      environment: existing.environment,
      name: "Another Template",
      trigger: existing.trigger,
      channel: "email",
      subject: "Subject",
      body: "Body"
    )
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:trigger], "has already been taken"
  end

  test "allows same trigger with different channel in same environment" do
    existing = templates(:welcome)
    whatsapp_version = Template.new(
      account: existing.account,
      environment: existing.environment,
      name: "Welcome WhatsApp",
      trigger: existing.trigger,
      channel: "whatsapp",
      body: "Welcome!"
    )
    assert whatsapp_version.valid?
  end

  test "allows same trigger in different environments" do
    existing = templates(:welcome)
    different_env = Template.new(
      account: accounts(:acme),
      environment: environments(:staging),
      name: "Welcome Staging",
      trigger: existing.trigger,
      channel: "email",
      subject: "Subject",
      body: "Body"
    )
    assert different_env.valid?
  end

  test "belongs to layout" do
    template = templates(:markdown_template)
    assert_equal layouts(:default_layout), template.layout
  end

  test "layout is optional" do
    template = templates(:welcome)
    assert_nil template.layout
    assert template.valid?
  end

  test "defaults body_format to html" do
    template = Template.new(
      account: accounts(:acme),
      environment: environments(:production),
      name: "Test",
      trigger: "test.default_format",
      channel: "email",
      body: "<p>hi</p>"
    )
    assert_equal "html", template.body_format
  end
end
