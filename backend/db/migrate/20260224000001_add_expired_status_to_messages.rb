class AddExpiredStatusToMessages < ActiveRecord::Migration[7.1]
  # Adds expired (20) to message status enum.
  # No schema change needed — status is an integer column and
  # the new value is handled purely in the Rails enum mapping.
  # This migration serves as documentation / timestamp marker.
  def change
    # intentionally blank — enum value added in Message model
  end
end
