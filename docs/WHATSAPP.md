# WhatsApp Cloud API + Business App coexistence

Messy connects to WhatsApp only through Meta's official Cloud API. With **coexistence**
a business keeps using the WhatsApp Business app on its phone while Messy receives and
sends on the same number. Both sides see the conversation.

```
WhatsApp Business app (phone) ⇄ same number ⇄ Meta Cloud API ⇄ POST /whatsapp/webhook ⇄ Messy inbox + API
```

## Data model (reuses the inbox)

| WhatsApp concept | Messy |
|---|---|
| Account / number (WABA, phone number id, token) | `WhatsappIntegration` (`integrations.config`), one per environment |
| Contact (`wa_id`) | `Customer` (`whatsapp_id`, `phone`) |
| Conversation | `Conversation` with `source: whatsapp`, one per (number, contact) |
| Message | `ConversationMessage`: `external_id` = Meta `wamid`, `delivery_status`, `metadata.whatsapp` = `{source, type, context_id, media, history, raw}` |
| Status history | `WhatsappMessageStatus` (`wamid`, `status`, `occurred_at`, `payload`) |
| Raw webhook | `WhatsappWebhookEvent` (verbatim body, `processed_at`, `error`) |

`metadata.whatsapp.source`:

- `customer`: an inbound message. Comes from the `messages` webhook, or from a history message sent by the contact.
- `business_app`: a message sent by a human in the Business app. Comes from `smb_message_echoes`, or from a history message sent by the business number.
- `api`: sent by Messy through the Cloud API.

History that predates onboarding is flagged `history: true`. Business-side history
messages are attributed to `business_app` because the number was on the app alone at
that time. The raw Meta message is always kept in `metadata.whatsapp.raw`.

## Processing and idempotency

`POST /whatsapp/webhook` runs these steps:

1. Checks `X-Hub-Signature-256` against the integration's `app_secret` or `META_APP_SECRET`.
2. Stores the body as a `WhatsappWebhookEvent`, keyed by the body's SHA-256.
3. Returns `200`.
4. Queues `ProcessWhatsappWebhookJob` to do the parsing.

Unique indexes make replays harmless:

- `(account_id, external_id)` on messages
- `(wamid, status)` on statuses
- `(account_id, whatsapp_id)` on customers
- one WhatsApp thread per `(account_id, visitor_token)`

A replayed or re-batched message creates nothing new. It also doesn't re-queue the media
download or re-fire the `whatsapp.inbound_message` notification. That
`ActiveSupport::Notifications` event is the hook for CRM or AI automation.

Statuses are tracked for every integration. Inbound conversations, echoes, history and
contacts are only captured when `config.inbox_enabled` is true. Embedded Signup turns it
on automatically. For older, send-only integrations you set it yourself.

Inbound media is downloaded by `DownloadWhatsappMediaJob`, outside the webhook
request. The file goes into Active Storage. Its links in the inbox JSON are signed and
expire after 1 hour.

## Customer service window

Free-form messages are only allowed within 24h of the contact's last inbound Cloud API
message. Outside that window you must send an approved template. Messages sent from the
Business app, and imported history, don't open or extend the window, following Meta's
coexistence rules.

The window is exposed in three places:

- `GET /whatsapp/window?to=`
- `whatsapp.free_form_allowed` / `window_expires_at` on the conversation detail
- a `422 code: template_required` response when a text send is refused

## API

| Endpoint | Auth | Purpose |
|---|---|---|
| `POST /whatsapp/messages` | environment API key or JWT | Send `{to, type: "text", text}` or `{to, type: "template", template: {name, language, components}}`. Returns `meta_message_id`, `conversation_id` and `window`. |
| `GET /whatsapp/window?to=` | API key or JWT | Whether free-form text is allowed right now |
| `POST /conversations/:id/create_message` | operator JWT | Inbox reply. In a WhatsApp conversation it is sent synchronously through the Cloud API. Accepts `template:` too. |
| `GET /whatsapp/embedded_signup` | workspace admin | Launch config for the browser: `app_id`, `config_id`, `extras` |
| `POST /whatsapp/embedded_signup` | workspace admin | `{code, waba_id, phone_number_id?, business_id?}`: exchanges the code, subscribes the app to the WABA and stores the number (details below) |
| `GET /whatsapp/diagnostics` | workspace admin | Config, a live Graph check (token validity, app subscription), last webhook, last inbound and outbound message, last error. Never returns secrets. |
| `GET/POST /whatsapp/webhook` | Meta | Verification and notifications |

After storing the number, `POST /whatsapp/embedded_signup` also enables the inbox and
starts the contacts and history sync (`WhatsappCoexistenceSyncJob`). Coexistence numbers
are **never** registered with `/register`, because they already are registered on the
Business app.

Graph calls go through `MetaGraph`. The API version is `META_GRAPH_API_VERSION`
(default `v26.0`).

## Server configuration

| Env var | What |
|---|---|
| `META_APP_ID` | Messy's Meta app (a Tech Provider app with the WhatsApp product) |
| `META_APP_SECRET` | Used to exchange the Embedded Signup code and verify webhook signatures |
| `WHATSAPP_VERIFY_TOKEN` | A random string you also paste into the Meta webhook settings |
| `META_ES_CONFIG_ID` | The Embedded Signup configuration id (Facebook Login for Business) |
| `META_GRAPH_API_VERSION` | Optional; defaults to `v26.0` |

Per-number values (access token, phone number id, WABA id) come from Embedded Signup and
are stored on the integration. They are never set as env vars.

Webhooks signed by the platform app only reach integrations whose WABA Embedded Signup
proved (`integrations.platform_verified_waba_id`). Integrations that bring their own Meta
app are authorized by their own `app_secret`. If you upgraded from v1.0.6 with numbers
already onboarded through Embedded Signup, run `bin/rails whatsapp:reverify` once. It
re-proves ownership through the Graph API.

## Meta setup (one time)

1. On developers.facebook.com, set up the app:
   - Add the WhatsApp product to a Business-type app.
   - Complete Business verification.
   - Become a Tech Provider, and get advanced access to `whatsapp_business_management` and `whatsapp_business_messaging`.
2. Configure the webhook under WhatsApp → Configuration:
   - Callback URL: `https://api.messy.sh/whatsapp/webhook`.
   - Verify token: the value of `WHATSAPP_VERIFY_TOKEN`.
   - Subscribe the fields `messages`, `smb_message_echoes`, `history`, `smb_app_state_sync` and `account_update`.
3. Set up Embedded Signup:
   - Under Facebook Login for Business → Configurations, create a WhatsApp Embedded Signup configuration.
   - Put its id in `META_ES_CONFIG_ID`.
   - Add `app.messy.sh` to Allowed Domains.
   - Add `https://app.messy.sh/` to Valid OAuth Redirect URIs.
4. Onboard a number:
   - In Messy, go to Integrations → WhatsApp → **Connect WhatsApp Business App**.
   - The business chooses to connect its existing WhatsApp Business app number.
   - It confirms on its phone. This needs Business app version 2.24.17 or later.
   - It agrees to share chat history.
   - Keep the app open while history syncs. Meta only allows the sync within 24h of onboarding.

## End-to-end check

1. `GET /whatsapp/diagnostics` should show:
   - `graph.ok: true`
   - `token_valid: true`
   - `subscribed_apps` containing the app
   - `onboarding.coexistence: true`
   - `coexistence_sync.requested_at`
2. From a customer phone, send a message to the business number. It should arrive on the business phone and appear in the Messy inbox as `source: customer`, and `last_webhook_at` / `last_inbound_at` should advance.
3. Reply from the WhatsApp Business app. The reply should appear in the inbox as `business_app`, from `smb_message_echoes`.
4. Send through the API:
   ```sh
   curl -X POST https://api.messy.sh/whatsapp/messages \
     -H "Authorization: Bearer $API_KEY" -H "Content-Type: application/json" \
     -d '{"to":"316...","type":"text","text":"Hello from Messy"}'
   ```
   The customer should receive it, and it should show up in the Business app on the phone.
5. `WhatsappMessageStatus` should gain `sent`, `delivered` and `read` rows for that `meta_message_id`.
6. Replay a stored event's body with the same signature, or run `ProcessWhatsappWebhookJob.perform_now(id)` again. The message count must not change.

## Limits under coexistence (from Meta)

- Throughput is 20 msg/s.
- Groups aren't synced.
- Disappearing messages, view-once, live location and broadcast lists are disabled on the phone.
- Linked companion devices must be re-linked after onboarding.
- Offboarding happens from the phone: Settings → Account → Business Platform → Disconnect. It arrives as an `account_update` `PARTNER_REMOVED` event, which diagnostics show as `last_account_update`.
