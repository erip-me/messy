class RuleResource
  include Alba::Resource

  OUTCOME_MAP = { 'deny' => 'block', 'allow' => 'deliver', 'redirect' => 'redirect' }.freeze

  attributes :id, :name, :condition, :redirect_to, :environment_id, :active,
             :created_at, :updated_at

  attribute :type, &:channel_type

  attribute :outcome do |rule|
    OUTCOME_MAP[rule.outcome] || rule.outcome
  end

  attribute :tags do |rule|
    rule.tags || []
  end

  attribute :environment_name do |rule|
    rule.environment&.name
  end
end
