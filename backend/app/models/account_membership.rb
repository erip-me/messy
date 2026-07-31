# Joins a User to an Account ("workspace" in the UI). One row per person per
# workspace; the role is per-workspace, so the same user can be an admin of one
# and a member of another.
class AccountMembership < ApplicationRecord
  belongs_to :user
  belongs_to :account

  # Mirrors User#role. :admin can manage users, environments and workspace
  # settings; :member has read/operate access only.
  enum :role, { member: 0, admin: 1 }, default: :member

  validates :user_id, uniqueness: { scope: :account_id }
end
