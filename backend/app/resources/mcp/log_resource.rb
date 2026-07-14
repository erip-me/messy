module Mcp
  class LogResource
    include Alba::Resource

    attributes :id, :tool_name, :status, :http_status, :duration_ms,
               :error_message, :arguments, :created_at

    attribute :user do |log|
      log.user && { id: log.user.id, name: log.user.name }
    end
  end
end
