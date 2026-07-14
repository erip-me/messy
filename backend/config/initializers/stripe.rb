# Stripe is configured via env vars (test key provided later). When the secret
# key is absent, billing endpoints respond 503 "not configured" rather than crash.
require "stripe"

Stripe.api_key = ENV["STRIPE_SECRET_KEY"] if ENV["STRIPE_SECRET_KEY"].present?
Stripe.api_version = "2024-06-20" if Stripe.api_key.present?
