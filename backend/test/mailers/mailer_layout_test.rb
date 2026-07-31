require "test_helper"

# ApplicationMailer sets `layout "mailer"`, so every mailer view is rendered into
# app/views/layouts/mailer.html.erb — which already supplies the doctype, the
# branded header and the footer.
#
# A view that is itself a full HTML document therefore produces a second
# <html> nested inside the layout's body. Clients handle that unpredictably:
# Gmail drops the inner <head>, taking any <style> block (and so all class-based
# styling) with it, and the layout's header renders on top of the view's own
# logo. Four views had drifted this way before this test existed.
class MailerLayoutTest < ActiveSupport::TestCase
  MAILER_VIEWS = Rails.root.glob("app/views/*_mailer/*.html.erb").freeze

  test "there are mailer views to check" do
    assert_operator MAILER_VIEWS.size, :>, 5, "glob stopped matching — fix the pattern"
  end

  test "mailer views are fragments, not whole documents" do
    offenders = MAILER_VIEWS.select { |f| f.read.match?(/<!DOCTYPE|<html[\s>]/i) }

    assert_empty relative(offenders),
                 "these render a second <html> inside layouts/mailer.html.erb — " \
                 "drop the doctype/head/body wrapper and keep only the content"
  end

  test "mailer views use inline styles, not a style block" do
    # Gmail and Outlook strip <style> from message bodies, so anything styled by
    # class silently renders unstyled.
    offenders = MAILER_VIEWS.select { |f| f.read.match?(/<style[\s>]/i) }

    assert_empty relative(offenders), "move these rules to inline style attributes"
  end

  private

  def relative(paths)
    paths.map { |p| p.relative_path_from(Rails.root).to_s }
  end
end
