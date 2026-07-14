require "test_helper"

class LayoutTest < ActiveSupport::TestCase
  fixtures :all

  test "validates name presence" do
    layout = layouts(:default_layout)
    layout.name = nil
    assert_not layout.valid?
    assert_includes layout.errors[:name], "can't be blank"
  end

  test "validates body presence" do
    layout = layouts(:default_layout)
    layout.body = nil
    assert_not layout.valid?
    assert_includes layout.errors[:body], "can't be blank"
  end

  test "validates body contains content placeholder" do
    layout = layouts(:default_layout)
    layout.body = "<html><body>No placeholder here</body></html>"
    assert_not layout.valid?
    assert_includes layout.errors[:body], "must contain a {{ content }} placeholder"
  end

  test "accepts body with {{ content }} placeholder" do
    layout = layouts(:default_layout)
    layout.body = "<html><body>{{ content }}</body></html>"
    assert layout.valid?
  end

  test "accepts body with {{content}} placeholder (no spaces)" do
    layout = layouts(:default_layout)
    layout.body = "<html><body>{{content}}</body></html>"
    assert layout.valid?
  end

  test "has many templates" do
    layout = layouts(:default_layout)
    assert_includes layout.templates, templates(:markdown_template)
  end

  test "stores transformers as JSON" do
    layout = layouts(:default_layout)
    assert_kind_of Hash, layout.transformers
    assert layout.transformers.key?("heading")
    assert layout.transformers.key?("paragraph")
    assert layout.transformers.key?("link")
  end

  test "defaults transformers to empty hash" do
    layout = Layout.new(
      account: accounts(:acme),
      environment: environments(:production),
      name: "New Layout",
      body: "<html>{{ content }}</html>"
    )
    assert_equal({}, layout.transformers)
  end

  test "empty transformers layout has no transformer rules" do
    layout = layouts(:empty_transformers_layout)
    assert_equal({}, layout.transformers)
  end
end
