require "test_helper"

module ApplicationCable
  class ConnectionTest < ActionCable::Connection::TestCase
    test "connects with valid JWT token" do
      user = users(:admin)
      token = JWT.encode({ id: user.id, exp: 24.hours.from_now.to_i }, Rails.application.secret_key_base)

      connect params: { token: token }

      assert_equal user.id, connection.current_user.id
      assert_equal user.account_id, connection.account_id
    end

    test "connects with visitor token and widget_key" do
      widget = chat_widget_settings(:acme_settings)

      connect params: { widget_key: widget.widget_key, visitor_token: "test_visitor_123" }

      assert_equal "test_visitor_123", connection.visitor_token
      assert_equal widget.account_id, connection.account_id
      assert_nil connection.current_user
    end

    test "rejects connection with visitor token and bare account_id (no widget_key)" do
      assert_reject_connection do
        connect params: { visitor_token: "test_visitor_123", account_id: accounts(:acme).id }
      end
    end

    test "rejects connection without credentials" do
      assert_reject_connection { connect }
    end

    test "rejects connection with expired JWT" do
      user = users(:admin)
      token = JWT.encode({ id: user.id, exp: 1.hour.ago.to_i }, Rails.application.secret_key_base)

      # With expired token and no visitor_token, should reject
      assert_reject_connection { connect params: { token: token } }
    end
  end
end
