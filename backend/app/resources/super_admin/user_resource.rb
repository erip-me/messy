module SuperAdmin
  # Cross-account user view for the super-admin console. Whitelisted: the old
  # inline as_json dumped every column, magic_link_token included.
  class UserResource
    include Alba::Resource

    attributes :id, :name, :email, :role, :is_super_admin, :account_id,
               :email_verified, :mcp_enabled, :last_login_at,
               :created_at, :updated_at

    attribute :account do |user|
      { id: user.account.id, name: user.account.name, plan: user.account.plan }
    end
  end
end

