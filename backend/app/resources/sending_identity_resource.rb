class SendingIdentityResource
  include Alba::Resource

  attributes :id, :account_id, :from_name, :from_email, :is_default,
             :created_at, :updated_at
end
