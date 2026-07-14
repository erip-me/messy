module SuperAdmin
  # Detail view: adds created_at on users, plus the account's environments.
  class AccountDetailResource < AccountResource
    attribute :environments do |account|
      account.environments.map do |e|
        { id: e.id, name: e.name, api_key: e.api_key, created_at: e.created_at }
      end
    end

    def user_summary(user)
      super.merge(created_at: user.created_at)
    end
  end
end
