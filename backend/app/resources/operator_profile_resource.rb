# The current operator's own profile (settings page).
class OperatorProfileResource
  include Alba::Resource

  attributes :id, :public_name, :bio, :availability, :auto_assign,
             :max_concurrent_chats

  attribute :avatar_url do |profile|
    profile.avatar.attached? ? Rails.application.routes.url_helpers.rails_blob_url(profile.avatar) : nil
  end

  attribute :online do |profile|
    profile.currently_online?
  end
end
