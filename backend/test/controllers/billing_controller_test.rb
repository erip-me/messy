require "test_helper"

class BillingControllerTest < ActionDispatch::IntegrationTest
  setup { Stripe.api_key = "sk_test_stub" }
  teardown { Stripe.api_key = nil }

  test "checkout is rejected when the account already has a subscription" do
    accounts(:acme).update!(stripe_subscription_id: "sub_existing")

    post "/billing/checkout", params: { plan: "byok" },
         headers: auth_headers(users(:admin)), as: :json

    assert_response :unprocessable_entity
    assert_match(/billing portal/, JSON.parse(response.body)["error"])
  end

  test "subscription deletion lands the account in an expired trial" do
    account = accounts(:acme)
    account.update!(plan: "byok", stripe_customer_id: "cus_test123", stripe_subscription_id: "sub_x")
    ENV["STRIPE_WEBHOOK_SECRET"] = "whsec_test"

    payload = { id: "evt_1", object: "event", type: "customer.subscription.deleted",
                data: { object: { object: "subscription", id: "sub_x", customer: "cus_test123" } } }.to_json
    ts = Time.now
    sig = Stripe::Webhook::Signature.compute_signature(ts, payload, "whsec_test")

    post "/billing/webhook", params: payload,
         headers: { "CONTENT_TYPE" => "application/json",
                    "Stripe-Signature" => "t=#{ts.to_i},v1=#{sig}" }

    assert_response :ok
    account.reload
    assert_equal "trial", account.plan
    assert account.trial_expired?
    assert_nil account.stripe_subscription_id
  ensure
    ENV.delete("STRIPE_WEBHOOK_SECRET")
  end
end
