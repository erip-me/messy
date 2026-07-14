# Team list entry (operator management page).
class OperatorProfileListResource
  include Alba::Resource

  attributes :id, :user_id, :public_name, :availability, :auto_assign,
             :max_concurrent_chats, :sort_order

  attribute :avatar_url do |profile|
    profile.avatar.attached? ? Rails.application.routes.url_helpers.rails_blob_url(profile.avatar) : nil
  end

  attribute :online do |profile|
    profile.currently_online?
  end
end
