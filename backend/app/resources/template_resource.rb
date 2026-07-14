class TemplateResource
  include Alba::Resource

  attributes :id, :account_id, :environment_id, :folder_id, :layout_id, :name,
             :trigger, :channel, :subject, :body, :body_format, :preview,
             :is_deleted, :created_at, :updated_at
end
