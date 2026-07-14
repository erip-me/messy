# Billing (Stripe)

Cloud plans are billed through **Stripe Checkout + the Stripe Customer Portal**, with a
webhook keeping each account's plan in sync. This approach gives upgrade/downgrade,
recurring billing, and **tax invoices** natively — no hand-rolled billing UI.

Self-hosters don't need any of this: with no Stripe keys set, the billing endpoints
return `503 "Billing is not configured"` and the in-app billing page shows a calm
"not enabled" notice. The open-source plan never touches Stripe.

## Plans

| Plan key  | Product            | Price    | Stripe price env       |
|-----------|--------------------|----------|------------------------|
| `free`    | Open source / self-host | €0  | — (no subscription)    |
| `byok`    | Cloud · BYOK       | €20/mo   | `STRIPE_PRICE_BYOK`    |
| `managed` | Cloud · Managed    | €60/mo   | `STRIPE_PRICE_MANAGED` |

Live prices are EUR, tax-exclusive (Stripe Tax adds VAT at checkout), lookup keys
`messy_byok_eur_monthly` / `messy_managed_eur_monthly`.

Plan definitions live in `app/models/account.rb` (`Account::PLANS`).

## Environment variables

```
STRIPE_SECRET_KEY=sk_test_...        # test or live secret key
STRIPE_WEBHOOK_SECRET=whsec_...      # signing secret of the /billing/webhook endpoint
STRIPE_PRICE_BYOK=price_...          # recurring €20/mo price ID
STRIPE_PRICE_MANAGED=price_...       # recurring €60/mo price ID
STRIPE_AUTOMATIC_TAX=false           # opt-out only; automatic tax is ON by default
```

If `STRIPE_SECRET_KEY` is unset, billing is simply off (graceful).

## One-time Stripe dashboard setup

1. **Products & prices** — create two recurring products ($20/mo and $60/mo). Copy each
   price ID into `STRIPE_PRICE_BYOK` / `STRIPE_PRICE_MANAGED`.
2. **Webhook** — add an endpoint pointing at `https://api.messy.sh/billing/webhook` and
   subscribe to:
   `checkout.session.completed`, `customer.subscription.created`,
   `customer.subscription.updated`, `customer.subscription.deleted`,
   `invoice.paid`, `invoice.payment_failed`.
   Copy the signing secret into `STRIPE_WEBHOOK_SECRET`.
3. **Customer Portal** — enable it in Stripe and allow plan switching between the two
   prices, cancellation, payment-method updates, and invoice history.
4. **Tax** — Stripe Tax is active (NL head office, NL VAT registration, defaults:
   tax-exclusive, tax code `txcd_10103001` SaaS). Checkout adds 21% NL VAT for Dutch
   customers; EU businesses with a valid VAT ID get the reverse charge (0%, noted on
   the invoice); non-EU customers are outside EU VAT scope. `tax_id_collection` is
   enabled at checkout and `billing_address_collection` is required so invoices carry
   an address. Set `STRIPE_AUTOMATIC_TAX=false` only to opt out (e.g. self-hosters
   reusing this code without Stripe Tax).

## Endpoints

| Method & path           | Purpose |
|-------------------------|---------|
| `GET /billing`          | Current plan + subscription state + plan catalog |
| `POST /billing/checkout`| Start a Checkout session for a paid plan → `{ url }` |
| `POST /billing/portal`  | Open the Customer Portal → `{ url }` |
| `GET /billing/invoices` | List tax invoices with downloadable PDFs |
| `POST /billing/webhook` | Stripe event sink (signature-verified) |

Mutating endpoints require an account **admin** JWT; the webhook is authenticated by
Stripe signature, not by API key.

## Local testing with the Stripe CLI

```bash
stripe listen --forward-to localhost:3300/billing/webhook   # prints a whsec_… to use as STRIPE_WEBHOOK_SECRET
stripe trigger checkout.session.completed
```

Use card `4242 4242 4242 4242` in test mode. After checkout completes, the webhook flips
the account's `plan` and `payment_status`, and invoices appear under
`GET /billing/invoices` and in the Customer Portal.
