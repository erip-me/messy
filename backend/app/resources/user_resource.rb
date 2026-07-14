# Whitelisted user representation for the dashboard. Never include
# magic_link_token or other secret columns — serializing the model directly
# would expose live login tokens.
class UserResource
  include Alba::Resource

  attributes :id, :name, :email, :role, :is_super_admin, :account_id,
             :last_login_at, :created_at, :updated_at

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
