class LayoutResource
  include Alba::Resource

  attributes :id, :account_id, :environment_id, :name, :body, :transformers,
             :is_deleted, :created_at, :updated_at
end
