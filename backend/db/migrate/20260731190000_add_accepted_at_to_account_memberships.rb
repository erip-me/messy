class AddAcceptedAtToAccountMemberships < ActiveRecord::Migration[8.0]
  # Membership is what grants access to a workspace, so a workspace admin must
  # not be able to attach someone else's existing login to their workspace
  # unilaterally — doing so handed them that person's profile. accepted_at gates
  # it: a cross-workspace invitation is a pending row until the invitee accepts.
  #
  # Every membership that exists today was either self-created (signup, or
  # creating a workspace) or the result of an invite the person could only use by
  # clicking a magic link, so consent is already established and they all
  # backfill as accepted. NULL therefore means "invited, not yet accepted", which
  # only new invitations can produce.
  def up
    add_column :account_memberships, :accepted_at, :datetime
    execute "UPDATE account_memberships SET accepted_at = created_at"
  end

  def down
    remove_column :account_memberships, :accepted_at
  end
end
