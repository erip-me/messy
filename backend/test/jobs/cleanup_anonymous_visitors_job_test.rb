require "test_helper"

class CleanupAnonymousVisitorsJobTest < ActiveSupport::TestCase
  test "deletes old anonymous customers with no conversations" do
    old_anon = Customer.create!(
      account: accounts(:acme),
      anonymous_token: "old_anon_token",
      first_name: "Old Anon",
      last_seen_at: 60.days.ago
    )

    assert_difference "Customer.count", -1 do
      CleanupAnonymousVisitorsJob.perform_now
    end

    assert_nil Customer.find_by(id: old_anon.id)
  end

  test "keeps anonymous customers with conversations" do
    anon = Customer.create!(
      account: accounts(:acme),
      anonymous_token: "anon_with_conv",
      first_name: "Anon With Conv",
      last_seen_at: 60.days.ago
    )

    Conversation.create!(
      account: accounts(:acme),
      environment: environments(:production),
      visitor_token: "anon_conv",
      visitor_name: "Anon",
      customer: anon,
      status: :open
    )

    assert_no_difference "Customer.count" do
      CleanupAnonymousVisitorsJob.perform_now
    end
  end

  test "keeps recent anonymous customers" do
    recent_anon = Customer.create!(
      account: accounts(:acme),
      anonymous_token: "recent_anon",
      first_name: "Recent Anon",
      last_seen_at: 5.days.ago
    )

    assert_no_difference "Customer.count" do
      CleanupAnonymousVisitorsJob.perform_now
    end

    assert Customer.find_by(id: recent_anon.id).present?
  end
end
