module Mcp
  # The MCP tool categories. These double as OAuth scopes: a client requests a
  # space-separated subset at /authorize, the user grants them at consent, and
  # tools/list is filtered to the granted set. `admin` is additionally gated by
  # the user's own account_admin? at call time (see ToolRegistry / dispatch).
  module Scopes
    ALL = %w[
      messaging templates audience segments campaigns automations
      channels inbox socials analytics admin
    ].freeze

    def self.supported
      ALL
    end

    # Parses a scope string into a clean, de-duplicated list of known scopes.
    # Blank / unknown input falls back to the full set (agents get everything the
    # user later consents to; the consent screen is where narrowing happens).
    def self.parse(str)
      requested = str.to_s.split(/\s+/).map(&:strip).reject(&:blank?)
      valid = requested & ALL
      valid.presence || ALL.dup
    end
  end
end
