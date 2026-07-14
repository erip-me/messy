module Mcp
  # An OAuth grant row on the MCP connections page.
  class ConnectionResource
    include Alba::Resource

    attributes :id, :scopes, :last_used_at, :created_at

    attribute :client_name do |grant|
      grant.mcp_client&.name
    end

    attribute :user do |grant|
      grant.user && { id: grant.user.id, name: grant.user.name, email: grant.user.email,
                      mcp_enabled: grant.user.mcp_enabled }
    end

    attribute :environment do |grant|
      grant.environment && { id: grant.environment.id, name: grant.environment.name }
    end

    attribute :revoked do |grant|
      grant.revoked?
    end

    attribute :enabled do |grant|
      grant.enabled?
    end
  end
end
