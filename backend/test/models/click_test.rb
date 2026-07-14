require "test_helper"

class ClickTest < ActiveSupport::TestCase
  fixtures :all

  test "validates url presence" do
    click = Click.new(
      account: accounts(:acme),
      message: messages(:email_one),
      url: nil,
      clicked_at: Time.current,
      ip_address: "1.2.3.4"
    )
    assert_not click.valid?
    assert_includes click.errors[:url], "can't be blank"
  end

  test "validates clicked_at presence" do
    click = Click.new(
      account: accounts(:acme),
      message: messages(:email_one),
      url: "https://example.com",
      clicked_at: nil
    )
    assert_not click.valid?
    assert_includes click.errors[:clicked_at], "can't be blank"
  end

  test "track_click creates record and updates message stats" do
    message = messages(:pending_email)
    assert_equal 0, message.click_count
    assert_nil message.first_clicked_at

    request = stub(remote_ip: "1.2.3.4", user_agent: "TestAgent", referer: "http://test.com")

    click = Click.track_click(message, "https://example.com/a", request)

    assert click.persisted?
    assert_equal "https://example.com/a", click.url
    assert_equal "1.2.3.4", click.ip_address
    assert_equal "TestAgent", click.user_agent
    assert_equal "http://test.com", click.referer
    assert_equal message, click.message

    message.reload
    assert_not_nil message.first_clicked_at
    assert_equal 1, message.click_count
  end

  test "track_click increments click_count on subsequent clicks" do
    message = messages(:email_one)
    message.update!(first_clicked_at: 6.hours.ago, click_count: 1)

    request = stub(remote_ip: "5.6.7.8", user_agent: "TestAgent2", referer: "http://test2.com")

    Click.track_click(message, "https://example.com/b", request)

    message.reload
    assert_equal 2, message.click_count
  end
end
