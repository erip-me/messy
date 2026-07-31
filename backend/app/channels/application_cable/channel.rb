module ApplicationCable
  class Channel < ActionCable::Channel::Base
    private

    # The workspace this subscription is for.
    #
    # Normally this is the connection-level account_id, which ApplicationCable::
    # Connection already resolved and membership-checked from the socket URL.
    # A subscription may still name a different workspace explicitly, in which case
    # it gets the same treatment: the id is a request, not authorization. Returns
    # nil when the caller isn't entitled to it, so channels can `reject`.
    def subscription_account_id
      return nil unless current_user

      requested = params[:account_id].presence
      return account_id if requested.blank?
      return account_id if requested.to_s == account_id.to_s

      account = Account.find_by(id: requested)
      return nil unless account && current_user.member_of?(account)

      account.id
    end
  end
end
