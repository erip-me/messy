# Full message row. Deliberately excludes `type` (matching Rails' as_json,
# which drops the STI column; clients use `channel` instead) and
# `tracking_salt` (the per-message HMAC salt — serializing it would let a
# client forge tracking links).
class MessageResource
  include Alba::Resource

  attributes :id, :account_id, :environment_id, :template_id, :trigger,
             :to, :cc, :bcc, :subject, :body, :tags, :scope, :status,
             :sent_at, :is_deleted, :created_at, :updated_at, :tracking_token,
             :open_count, :first_opened_at, :parent_message_id, :language,
             :drip_campaign_id, :drip_step_id, :sending_identity_id,
             :click_count, :first_clicked_at
end
