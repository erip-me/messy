module SuperAdmin
  # Detail view: the nested account also carries billing state.
  class UserDetailResource < UserResource
    attribute :account do |user|
      user.account.slice(:id, :name, :plan, :trial_ends_at, :payment_status).symbolize_keys
    end
  end
end
