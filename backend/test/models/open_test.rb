require "test_helper"

class OpenTest < ActiveSupport::TestCase
  fixtures :all

  test "validates opened_at presence" do
    open_record = Open.new(
      account: accounts(:acme),
      message: messages(:email_one),
      opened_at: nil,
      ip_address: "1.2.3.4"
    )
    assert_not open_record.valid?
    assert_includes open_record.errors[:opened_at], "can't be blank"
  end

  test "validates ip_address presence" do
    open_record = Open.new(
      account: accounts(:acme),
      message: messages(:email_one),
      opened_at: Time.current,
      ip_address: nil
    )
    assert_not open_record.valid?
    assert_includes open_record.errors[:ip_address], "can't be blank"
  end

  test "track_open creates record and updates message stats" do
    message = messages(:pending_email)
    assert_equal 0, message.open_count
    assert_nil message.first_opened_at

    request = stub(remote_ip: "1.2.3.4", user_agent: "TestAgent", referer: "http://test.com")

    open_record = Open.track_open(message, request)

    assert open_record.persisted?
    assert_equal "1.2.3.4", open_record.ip_address
    assert_equal "TestAgent", open_record.user_agent
    assert_equal "http://test.com", open_record.referer
    assert_equal message, open_record.message

    message.reload
    assert_not_nil message.first_opened_at
    assert_equal 1, message.open_count
  end

  test "track_open increments open_count on subsequent opens" do
    message = messages(:email_one)
    # Fixture has open_count: 1 and first_opened_at set
    assert_equal 1, message.open_count
    assert_not_nil message.first_opened_at

    request = stub(remote_ip: "5.6.7.8", user_agent: "TestAgent2", referer: "http://test2.com")

    Open.track_open(message, request)

    message.reload
    assert_equal 2, message.open_count
  end
end
