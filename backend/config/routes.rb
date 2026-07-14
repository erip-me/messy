Rails.application.routes.draw do
  # Job queue monitoring available via `bin/rails solid_queue:status`

  root 'home#index'

  # ── MCP server (agents: Claude, OpenAI, ...) ────────────────────────────────
  # OAuth 2.1 discovery + authorization server.
  get  '/.well-known/oauth-authorization-server', to: 'mcp/oauth/metadata#authorization_server'
  get  '/.well-known/oauth-protected-resource',   to: 'mcp/oauth/metadata#protected_resource'
  post '/oauth/register',  to: 'mcp/oauth/registrations#create'
  get  '/oauth/authorize', to: 'mcp/oauth/authorizations#new'
  post '/oauth/authorize', to: 'mcp/oauth/authorizations#create'
  post '/oauth/token',     to: 'mcp/oauth/tokens#create'
  post '/oauth/revoke',    to: 'mcp/oauth/tokens#revoke'

  # Streamable-HTTP MCP endpoint. POST = JSON-RPC tool calls; GET = SSE stream.
  post '/mcp', to: 'mcp/server#handle'
  get  '/mcp', to: 'mcp/stream#show'

  # Dashboard management (admin-only): master switch, connections, usage logs.
  scope '/mcp' do
    get    'settings',        to: 'mcp/management#show'
    patch  'settings',        to: 'mcp/management#update'
    get    'connections',     to: 'mcp/management#connections'
    delete 'connections/:id', to: 'mcp/management#revoke_connection'
    patch  'users/:user_id',  to: 'mcp/management#set_user_enabled'
    get    'logs',            to: 'mcp/management#logs'
  end

  post '/signup', to: 'signups#create'

  # Public contact / enterprise enquiry form on the marketing site.
  post '/contact', to: 'contacts#create'

  resources :accounts do
    member do
      patch :onboarding
    end
  end

  resources :environments do
    member do
      post :toggle_channel
      post :test
    end
  end
  resources :users do
    get :me, on: :collection
  end

  resources :integrations do
    member do
      post :test
    end
  end
  resources :messages do
    collection do
      post :trigger
    end
    member do
      post :retry_delivery
      get 'attachments/:attachment_id', action: :attachment, as: :attachment
    end
  end
  resources :templates
  resources :layouts
  post '/sync', to: 'sync#create'
  resources :folders do
    member do
      post :move
    end
  end
  resources :rules

  post '/customers/identify', to: 'customer_identify#identify'
  resources :whatsapp_templates, only: [:index]
  resources :device_tokens, only: [:index, :create, :update, :destroy] do
    collection do
      post :unregister
    end
  end
  resources :customers, only: [:index, :show, :destroy] do
    collection do
      get :recent_activities
      get :export
    end
    member do
      post :toggle_unsubscribe
      post :toggle_category_unsubscribe
      post :unsubscribe_all
    end
  end

  resources :segments do
    collection do
      post :preview
      get  :attributes
    end
    member do
      post :clean
    end
  end
  resources :csv_imports, only: [:index, :show] do
    collection do
      post :upload
    end
    member do
      post :validate
      post :start
    end
  end

  # Super Admin routes
  namespace :admin, module: :super_admin do
    resources :accounts do
      resources :users, only: [:index]
    end
    resources :users do
      member do
        post :toggle_super_admin
      end
    end
  end

  get 'dashboard/stats', to: 'dashboard#stats'

  # Email finder tool
  post 'tools/email_finder/generate', to: 'email_finder#generate'
  post 'tools/email_finder/verify', to: 'email_finder#verify'
  post 'tools/email_finder/verify_stream', to: 'email_finder#verify_stream'

  resources :magic_links, only: [:create] do
    collection do
      get :validate
      delete '/logout', to: 'magic_links#destroy'
    end
  end

  # WhatsApp Meta webhook (verification + status callbacks)
  get  'whatsapp/webhook', to: 'whatsapp_webhooks#verify'
  post 'whatsapp/webhook', to: 'whatsapp_webhooks#callback'

  # SES SNS webhook (delivery, bounce, complaint notifications)
  post 'ses/webhook', to: 'ses_webhooks#callback'

  resources :campaigns do
    member do
      post :send_campaign
      post :send_test
      get  :deliveries
      post :retry_delivery
      post :retry_all_failed
    end
  end

  resources :drips do
    collection do
      post :projection
    end
    member do
      post :activate
      post :pause
    end
  end

  resources :sending_identities, only: [:index, :create, :update, :destroy]

  # Socials — per-region content calendar + auto-posting buffer (dashboard, admin).
  resources :social_regions, only: %i[index show create update destroy]

  # Graph-API discovery for a Meta credential (populates a region's dropdowns).
  get 'integrations/:id/meta/pages',       to: 'meta_discovery#pages'
  get 'integrations/:id/meta/ad_accounts', to: 'meta_discovery#ad_accounts'
  get 'integrations/:id/meta/instagram',   to: 'meta_discovery#instagram'
  get 'integrations/:id/meta/instagram_accounts', to: 'meta_discovery#instagram_accounts'

  # LinkedIn OAuth connect + discovery for a LinkedIn credential.
  get 'integrations/:id/linkedin/oauth_url',      to: 'linkedin_discovery#oauth_url'
  get 'integrations/:id/linkedin/organizations',  to: 'linkedin_discovery#organizations'
  get 'social/oauth/linkedin/callback',           to: 'social_oauth#linkedin_callback'
  get  'social_regions/:region_id/calendar',      to: 'social_posts#calendar'
  post 'social_regions/:region_id/social_posts',  to: 'social_posts#create'

  get   'social_posts/:id',              to: 'social_posts#show'
  patch 'social_posts/:id',              to: 'social_posts#update'
  post  'social_posts/:id/alternatives', to: 'social_posts#create_alternative'
  post  'social_posts/:id/publish_now',  to: 'social_posts#publish_now'
  get   'social_posts/:id/deliveries',   to: 'social_posts#deliveries'

  patch  'social_alternatives/:id',          to: 'social_alternatives#update'
  delete 'social_alternatives/:id',          to: 'social_alternatives#destroy'
  post   'social_alternatives/:id/post_now', to: 'social_alternatives#post_now'

  # Socials content provisioning (environment API key auth).
  post 'socials/provision', to: 'socials/provisioning#create'

  get 'campaign_track/:token/open.png',      to: 'campaign_tracking#open', as: 'campaign_track_open'
  get 'campaign_track/:token/click',         to: 'campaign_tracking#click', as: 'campaign_track_click'
  get  'campaign_track/:token/unsubscribe',  to: 'campaign_tracking#unsubscribe', as: 'campaign_unsubscribe'
  post 'campaign_track/:token/resubscribe',  to: 'campaign_tracking#resubscribe', as: 'campaign_resubscribe'
  get  'campaign_track/test_unsubscribe',    to: 'campaign_tracking#test_unsubscribe', as: 'campaign_test_unsubscribe'

  # Tracking pixel route
  get 'track/:token', to: 'tracking#pixel', constraints: { token: /[a-f0-9]{64}\.png/ }
  # Transactional click-tracking redirect
  get 'track/:token/click', to: 'tracking#click', as: 'track_click', constraints: { token: /[a-f0-9]{64}/ }
  # Transactional / drip unsubscribe link
  get 'track/:token/unsubscribe', to: 'tracking#unsubscribe', as: 'track_unsubscribe', constraints: { token: /[a-f0-9]{64}/ }

  # Help desk
  # Provider OAuth callbacks + cloud-push receivers (unauthenticated: called by
  # the browser redirect / Google Pub/Sub / Microsoft Graph). Declared before the
  # resources so the static paths aren't captured as :id.
  get  'mailboxes/oauth/google/callback',    to: 'mailbox_oauth#google_callback'
  get  'mailboxes/oauth/microsoft/callback', to: 'mailbox_oauth#microsoft_callback'
  post 'mailboxes/gmail/push',               to: 'mailbox_push#gmail'
  post 'mailboxes/graph/push',               to: 'mailbox_push#graph'
  resources :mailboxes do
    member do
      post :test_connection
      get  :oauth_url
    end
  end
  get 'helpdesk/stats', to: 'helpdesk#stats'

  # Operator chat inbox
  resources :conversations, only: [:index, :show, :update] do
    member do
      get :messages
      post :create_message
      post :assign
      post :transfer
      post :snooze
      post :mark_read
      post :mark_unread
      post :add_tag
      delete 'tags/:tag_id', action: :remove_tag, as: :remove_tag
      get :email_detail
    end
    collection do
      get :search
      get :stats
    end
  end

  # Start chat from customer page
  resources :customers, only: [] do
    resources :conversations, only: [:create], controller: 'conversations'
  end

  # Billing (Stripe Checkout + Customer Portal + webhook)
  get  'billing',          to: 'billing#show'
  get  'billing/invoices', to: 'billing#invoices'
  post 'billing/checkout', to: 'billing#checkout'
  post 'billing/portal',   to: 'billing#portal'
  post 'billing/webhook',  to: 'billing#webhook'

  # Chat settings
  get  'chat_settings', to: 'chat_settings#show'
  patch 'chat_settings', to: 'chat_settings#update'
  resources :conversation_tags, only: [:index, :create, :update, :destroy]
  resources :canned_responses, only: [:index, :create, :update, :destroy]

  # Operator profile
  get  'operator_profile', to: 'operator_profiles#show'
  patch 'operator_profile', to: 'operator_profiles#update'
  post 'operator_profile/heartbeat', to: 'operator_profiles#heartbeat'
  get  'operator_profiles', to: 'operator_profiles#index'
  patch 'operator_profiles/reorder', to: 'operator_profiles#reorder'

  # Widget API (public, visitor-token auth)
  namespace :widget, defaults: { format: :json } do
    get  'v1/config',                              to: 'config#show'
    post 'v1/conversations',                       to: 'conversations#create'
    get  'v1/conversations',                       to: 'conversations#index'
    get  'v1/conversations/:id/messages',           to: 'conversations#messages'
    post 'v1/conversations/:id/messages',           to: 'conversations#create_message'
    post 'v1/conversations/:id/read',               to: 'conversations#mark_read'
    post 'v1/conversations/:id/rate',               to: 'conversations#rate'
    post 'v1/offline',                             to: 'offline#create'
    post 'v1/identify',                            to: 'identity#identify'
    get  'v1/unread_count',                        to: 'unread#show'
  end

  mount ActionCable.server => '/cable'

  get 'up' => 'rails/health#show', as: :rails_health_check

  match "*unmatched", to: "application#render_404", via: :all,
        constraints: ->(req) { !req.path.start_with?("/rails/active_storage") }
end
