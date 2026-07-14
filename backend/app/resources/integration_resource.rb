class IntegrationResource
  include Alba::Resource

  attributes :id, :account_id, :environment_id, :kind, :vendor, :active,
             :created_at, :updated_at

  # STI type; as a plain attribute it would be swallowed by ActiveRecord.
  attribute :type, &:type

  # Provider credentials go out masked, never raw (see ConfigSecretFiltering).
  attribute :config do |integration|
    cfg = integration.config
    cfg.is_a?(Hash) ? integration.class.filter_secret_config(cfg) : cfg
  end

  attribute :environment_name do |integration|
    integration.environment&.name
  end
end
