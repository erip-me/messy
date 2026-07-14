require "test_helper"

class UnsnoozeConversationsJobTest < ActiveSupport::TestCase
  test "reopens conversations past snooze time" do
    conv = conversations(:snoozed_chat)
    conv.update!(snoozed_until: 1.minute.ago)

    UnsnoozeConversationsJob.perform_now

    conv.reload
    assert conv.open?
    assert_nil conv.snoozed_until
  end

  test "does not reopen conversations not yet due" do
    conv = conversations(:snoozed_chat)
    # snoozed_until is 1 hour from now in fixture

    UnsnoozeConversationsJob.perform_now

    conv.reload
    assert conv.snoozed?
  end
end
