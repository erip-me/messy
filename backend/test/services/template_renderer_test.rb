require "test_helper"

class TemplateRendererTest < ActiveSupport::TestCase
  setup do
    @account = accounts(:acme)
    @environment = environments(:production)
    @layout = layouts(:default_layout)
  end

  def template(attrs = {})
    @account.templates.create!({
      environment: @environment,
      name: "T",
      trigger: "test.#{SecureRandom.hex(6)}",
      channel: "email",
      subject: "Hi {{first_name}}",
      body: "Hello {{first_name}}",
      body_format: "html"
    }.merge(attrs))
  end

  test "markdown body is converted to HTML so paragraph breaks survive" do
    t = template(body_format: "markdown", layout: @layout,
                 body: "First paragraph.\n\nSecond paragraph.")

    body = TemplateRenderer.call(template: t, variables: {}).body

    # Each blank-line-separated paragraph becomes its own transformed <p>, not
    # one run-on line — this is the drip bug we are guarding against.
    assert_includes body, "<p style=\"font-size: 16px;\">First paragraph.</p>"
    assert_includes body, "<p style=\"font-size: 16px;\">Second paragraph.</p>"
  end

  test "markdown body is wrapped in the layout" do
    t = template(body_format: "markdown", layout: @layout, body: "Body.")

    body = TemplateRenderer.call(template: t, variables: {}).body

    assert_includes body, "<html><body>"
    assert_includes body, "</body></html>"
  end

  test "Liquid variables are interpolated in subject and body" do
    t = template(body_format: "markdown", layout: @layout, body: "Hi {{first_name}}")

    rendered = TemplateRenderer.call(template: t, variables: { "first_name" => "Ann" })

    assert_equal "Hi Ann", rendered.subject
    assert_includes rendered.body, "Hi Ann"
  end

  test "html body is passed through untransformed" do
    t = template(body_format: "html", layout: nil, body: "<b>Hi {{first_name}}</b>")

    body = TemplateRenderer.call(template: t, variables: { "first_name" => "Ann" }).body

    assert_equal "<b>Hi Ann</b>", body
  end

  test "push channel is left as plain text (no markdown transform, no layout)" do
    t = template(channel: "push", body_format: "markdown", layout: @layout,
                 subject: nil, body: "First.\n\nSecond.")

    body = TemplateRenderer.call(template: t, variables: {}).body

    assert_equal "First.\n\nSecond.", body
    assert_not_includes body, "<p"
  end
end
