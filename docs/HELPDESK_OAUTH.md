# Helpdesk mailbox OAuth + cloud push — setup guide

The helpdesk polls support mailboxes and turns inbound email into tickets. Three
connection types are supported:

| Provider | Auth | New mail arrives via |
|---|---|---|
| `imap` | host/username/password | 2-minute poll |
| `gmail` | Google OAuth (central app) | **Gmail push** (Cloud Pub/Sub) → callback; poll as fallback |
| `office365` | Microsoft OAuth (central app) | **Graph change notifications** → callback; poll as fallback |

There is **one** Google OAuth client and **one** Azure app for the whole
platform. Customers never paste client secrets — they click **Connect** on a
mailbox and grant consent. Sending replies is unchanged (still SMTP/SES via the
environment's email integration); OAuth here is read-only for ingestion.

Fill in the env vars in the `backend-env` k8s secret (namespace `messy`).
`API_URL` (`https://api.messy.sh`) and `FRONTEND_URL` (`https://app.messy.sh`)
already exist and are reused for the redirect and notification URLs below.

---

## A. Google — Gmail OAuth + Pub/Sub push

You need a Google Cloud project. Use an existing one or create a new project at
<https://console.cloud.google.com> (top bar → project picker → **New Project**,
e.g. `messy-helpdesk`). Note the **Project ID** — it goes in the topic name.

### A1. Enable APIs

APIs & Services → **Enable APIs and Services**, enable both:
- **Gmail API**
- **Cloud Pub/Sub API**

### A2. OAuth consent screen

APIs & Services → **OAuth consent screen**:
1. User type **External** → Create.
2. App name (e.g. "Messy Helpdesk"), support email, developer contact.
3. **Scopes** → Add → add `.../auth/gmail.readonly` (that one scope is enough to
   read mail and to run `watch` for push). Save.
4. **Publishing status**: click **Publish app** and submit for verification.
   - `gmail.readonly` is a *restricted* scope, so Google requires app
     verification (brand + security review) before external users outside your
     org can connect. Until then, add each mailbox owner under **Test users** —
     test users work immediately, capped at 100.

### A3. OAuth client credentials

APIs & Services → **Credentials** → Create credentials → **OAuth client ID**:
- Application type **Web application**.
- **Authorized redirect URIs** → add:
  - `https://api.messy.sh/mailboxes/oauth/google/callback`
- Create → copy the **Client ID** and **Client secret**.

→ `GOOGLE_OAUTH_CLIENT_ID`, `GOOGLE_OAUTH_CLIENT_SECRET`

### A4. Pub/Sub topic + push subscription (this is what enables push)

Pub/Sub → **Topics** → **Create topic**:
- Topic ID `messy-gmail-push` (leave "Add a default subscription" unchecked).
- Full name will be `projects/<PROJECT_ID>/topics/messy-gmail-push`.

→ `GMAIL_PUBSUB_TOPIC=projects/<PROJECT_ID>/topics/messy-gmail-push`

**Grant Gmail permission to publish to the topic** (required, or `watch` fails):
- Open the topic → **Permissions** tab / **Add principal**.
- New principal: `gmail-api-push@system.gserviceaccount.com`
- Role: **Pub/Sub Publisher**. Save.

**Create the push subscription** that forwards to our callback:
- On the topic → **Create subscription**.
- Subscription ID `messy-gmail-push-sub`.
- Delivery type **Push**.
- Endpoint URL:
  `https://api.messy.sh/mailboxes/gmail/push?token=<GMAIL_PUSH_TOKEN>`
  where `<GMAIL_PUSH_TOKEN>` is a random secret you generate (e.g.
  `openssl rand -hex 24`). The backend rejects any push whose `token` query
  param doesn't match.
- Leave "Enable authentication" off (the shared token is the guard). Create.

→ `GMAIL_PUSH_TOKEN=<the random secret>`

> When a mailbox connects, the backend calls `users.watch` with the topic above.
> Google then publishes to the topic on every new INBOX message; the push
> subscription POSTs to our callback; we fetch the new mail by stored
> `historyId`. A watch lasts 7 days and is auto-renewed daily.

### Google env summary
```
GOOGLE_OAUTH_CLIENT_ID=...apps.googleusercontent.com
GOOGLE_OAUTH_CLIENT_SECRET=...
GMAIL_PUBSUB_TOPIC=projects/<PROJECT_ID>/topics/messy-gmail-push
GMAIL_PUSH_TOKEN=<random secret, must match the ?token= on the push subscription>
```

---

## B. Microsoft — Office365 OAuth + Graph push

At <https://portal.azure.com> → **Microsoft Entra ID** (formerly Azure AD) → **App
registrations**.

### B1. Register the app

**New registration**:
- Name e.g. "Messy Helpdesk".
- **Supported account types**: *Accounts in any organizational directory and
  personal Microsoft accounts* → this maps to tenant **`common`** (any Microsoft
  365 org **and** outlook.com/hotmail can connect).
- **Redirect URI**: platform **Web** →
  `https://api.messy.sh/mailboxes/oauth/microsoft/callback`
  (add the `test-api` one too after creation, under **Authentication**).
- Register → copy **Application (client) ID**.

→ `MS_OAUTH_CLIENT_ID`

### B2. Client secret

**Certificates & secrets** → **New client secret** → set expiry (e.g. 24 months)
→ copy the **Value** immediately (shown once).

→ `MS_OAUTH_CLIENT_SECRET`

### B3. API permissions

**API permissions** → Add a permission → **Microsoft Graph** → **Delegated
permissions**, add:
- `Mail.Read`  — read the mailbox and create Graph subscriptions on it
- `offline_access` — issues the refresh token
- `openid`, `email`, `profile`, `User.Read` — sign-in + identify the mailbox

Delegated permissions are consented by each connecting user, so **admin consent
is not required** for `common`. (If a customer's tenant enforces admin consent,
their admin approves once.)

### B4. Push (no portal step)

Graph push needs no Azure configuration. When a mailbox connects, the backend
creates a Graph **subscription** with:
- `notificationUrl = https://api.messy.sh/mailboxes/graph/push`
- `resource = me/mailFolders('inbox')/messages`, `changeType = created`
- a `clientState` secret (set `GRAPH_WEBHOOK_CLIENT_STATE` below; the callback
  rejects notifications whose `clientState` doesn't match).

Graph immediately calls the notification URL once with a `validationToken` to
prove we own it — the backend echoes it. Mail subscriptions live ~3 days and are
auto-renewed every 6 hours.

→ `GRAPH_WEBHOOK_CLIENT_STATE=<random secret, e.g. openssl rand -hex 24>`

### Microsoft env summary
```
MS_OAUTH_CLIENT_ID=<application (client) id>
MS_OAUTH_CLIENT_SECRET=<client secret value>
MS_OAUTH_TENANT=common
GRAPH_WEBHOOK_CLIENT_STATE=<random secret>
```

---

## C. Apply the env vars

Add the keys to the `backend-env` secret and restart the workloads (the **worker**
runs the poll/watch/subscribe/renew jobs, so it needs them too):

```bash
kubectl edit secret backend-env -n messy   # add keys (base64)
kubectl rollout restart deployment/backend deployment/worker -n messy
```

If you manage these through Terraform, add them to the backend secret in
`deploy/modules` and `terraform apply` instead.

---

## D. Verify end-to-end

1. In the app: **Helpdesk → Mailboxes → New**, pick **Gmail** (or **Office365**),
   save, then click **Connect** and complete the consent screen. You return to
   the mailboxes list with the mailbox showing **Connected** and **Push active**.
2. Send a test email to that address. It should appear as a ticket within a few
   seconds (push), not the 2-minute poll cadence.
3. If push shows inactive, the mailbox still works via polling. Check the worker
   logs for `[GmailPush]` / `[GraphPush]` and confirm:
   - Gmail: the `gmail-api-push@system.gserviceaccount.com` publisher grant and
     the `?token=` on the subscription match `GMAIL_PUSH_TOKEN`.
   - Graph: `GRAPH_WEBHOOK_CLIENT_STATE` matches and `API_URL` is publicly
     reachable (Graph validates the notification URL on subscribe).
