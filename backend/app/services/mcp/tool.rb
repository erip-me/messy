module Mcp
  # One MCP tool = one existing REST endpoint plus the metadata an agent needs to
  # call it. `scope` maps to an OAuth scope / tool category; `admin` tools are
  # additionally hidden from non-admins in tools/list (and enforced by the reused
  # controller). Path placeholders look like "{id}" and are filled from args named
  # in `path_params`. Remaining args become the JSON body (wrapped under `body_key`
  # when the target controller expects params.require(:key)), except those named
  # in `query_params`, which go on the query string.
  Tool = Struct.new(
    :name, :description, :scope, :admin, :method, :path,
    :input_schema, :path_params, :query_params, :body_key,
    keyword_init: true
  ) do
    def admin?
      admin == true
    end

    def http_method
      method || :get
    end

    def path_keys
      Array(path_params)
    end

    def query_keys
      Array(query_params)
    end

    # The shape returned to clients from tools/list.
    def definition
      {
        name: name,
        description: description,
        inputSchema: input_schema || { "type" => "object", "properties" => {} }
      }
    end
  end
end
