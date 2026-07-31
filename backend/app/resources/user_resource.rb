# Whitelisted user representation for the dashboard. Never include
# magic_link_token or other secret columns — serializing the model directly
# would expose live login tokens.
class UserResource
  include Alba::Resource

  attributes :id, :name, :email, :is_super_admin, :account_id,
             :last_login_at, :created_at, :updated_at

  # Role is per-workspace (AccountMembership#role), so pass params[:account] to
  # report the role in the workspace being viewed. Without it we fall back to the
  # user's default workspace, which is what single-workspace callers expect.
  attribute :role do |user|
    user.role_in(params[:account] || user.account)
  end

  attribute :operator_profile do |user|
    profile = user.operator_profile
    if profile
      {
        public_name: profile.public_name,
        avatar_url: profile.avatar.attached? ? Rails.application.routes.url_helpers.rails_blob_url(profile.avatar) : nil,
        online: profile.currently_online?
      }
    end
  end
end
