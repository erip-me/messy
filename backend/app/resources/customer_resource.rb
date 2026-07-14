# Bare customer row. Never include anonymous_token — it's the widget visitor's
# session credential.
class CustomerResource
  include Alba::Resource

  attributes :id, :account_id, :email, :first_name, :last_name, :phone,
             :custom_attributes, :unsubscribed_channels, :unsubscribed_categories,
             :email_score, :email_score_checked_at, :last_engaged_at,
             :last_seen_at, :online, :browser, :os, :country, :city,
             :current_page_url, :current_page_title, :created_at, :updated_at
end
