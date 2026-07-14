# Masks secret values held in a model's JSONB `config` (and similar credential
# columns) when serialized to JSON, so the API never discloses third-party
# provider credentials. The mask is a sentinel string, so the client can tell a
# credential is configured without seeing it; writers must run incoming config
# through #merge_filtered_config so a round-trip edit doesn't overwrite the real
# secret with the sentinel.
module ConfigSecretFiltering
  extend ActiveSupport::Concern

  SENSITIVE_CONFIG_KEYS = %w[
    secret_access_key secret_key password token auth_token
    webhook_verify_token app_secret server_key private_key
    vapid_private_key access_token client_secret refresh_token api_key
  ].freeze

  FILTERED = "[FILTERED]".freeze

  def as_json(options = {})
    json = super
    if json["config"].is_a?(Hash)
      json["config"] = self.class.filter_secret_config(json["config"])
    end
    json
  end

  # Merge incoming config onto the persisted config, dropping any sentinel
  # placeholders so unchanged secrets are preserved.
  def merge_filtered_config(incoming)
    incoming = incoming.to_unsafe_h if incoming.respond_to?(:to_unsafe_h)
    cleaned = (incoming || {}).to_h.reject { |_, v| v == FILTERED }
    (config || {}).merge(cleaned)
  end

  class_methods do
    def filter_secret_config(cfg)
      cfg.each_with_object({}) do |(key, value), filtered|
        filtered[key] =
          if SENSITIVE_CONFIG_KEYS.include?(key.to_s) && value.present?
            FILTERED
          else
            value
          end
      end
    end
  end
end
