class FolderResource
  include Alba::Resource

  attributes :id, :account_id, :environment_id, :parent_folder_id, :name,
             :is_deleted, :created_at, :updated_at
end
