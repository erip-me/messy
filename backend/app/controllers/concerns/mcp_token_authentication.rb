# Resolves an MCP access token (Authorization: Bearer <access_token>) to its
# grant. A missing/invalid/revoked token yields a 401 carrying the
# WWW-Authenticate hint that points clients at OAuth discovery (the MCP-spec
# handshake). A token that resolves but whose grant is gated off (account master
# off, user disabled) still authenticates here — the per-call gate rejects it in
# the handler so it can be logged as `rejected` rather than a transport 401.
module McpTokenAuthentication
  extend ActiveSupport::Concern

  private

  def mcp_bearer_token
    header = request.headers["Authorization"]
    return nil unless header&.start_with?("Bearer ")
    header.split(" ", 2).last
  end

  def current_mcp_access_token
    return @current_mcp_access_token if defined?(@current_mcp_access_token)
    @current_mcp_access_token = McpToken.authenticate(mcp_bearer_token, kind: :access)
  end

  def current_mcp_grant
    current_mcp_access_token&.mcp_grant
  end

  def require_mcp_token!
    return true if current_mcp_grant
    render_mcp_unauthorized
    false
  end

  def render_mcp_unauthorized
    metadata = "#{request.base_url}/.well-known/oauth-protected-resource"
    response.set_header("WWW-Authenticate", %(Bearer resource_metadata="#{metadata}"))
    render json: { jsonrpc: "2.0", id: nil, error: { code: -32001, message: "Unauthorized" } },
           status: :unauthorized
  end
end
