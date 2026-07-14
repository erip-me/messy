module Mcp
  module Oauth
    # PKCE (RFC 7636) verification. Only S256 is accepted — the plain method is
    # rejected per OAuth 2.1.
    module Pkce
      def self.verify(verifier, challenge, method = "S256")
        return false if verifier.blank? || challenge.blank?
        return false unless method == "S256"

        computed = Base64.urlsafe_encode64(Digest::SHA256.digest(verifier), padding: false)
        ActiveSupport::SecurityUtils.secure_compare(computed, challenge)
      end
    end
  end
end
