# Socials — per-region social content calendar (as built)

A social-media buffer / scheduler. A
per-region content calendar: each day holds AI-generated creative "alternatives";
an operator picks which creative goes out, edits copy, marks the day **ready**, and
a scheduled job auto-posts ready days to the region's linked channels at its local
time. Channels: **Facebook Pages**, their linked **Instagram**, and **LinkedIn**
organization pages. Content can be pushed in in bulk via a **provisioning API**.

> **Imagery is required.** A day can only be readied (and only publishes) when a
> selected creative carries an image or video. Text-only posts are rejected: the
> UI blocks "Mark ready" / "Publish now" and the model refuses a `ready` status
> without media. LinkedIn also posts imagery only for now (a video feed/reel slot
> is skipped for LinkedIn; carousels are images).

Access: **account admins** (dashboard controllers use `authenticate_user!` +
`require_account_admin!`). Everything is account-scoped.

> This doc reflects the shipped implementation. Two design decisions shaped it:
> **a region links to many social accounts** (N:M), and the **provisioning API
> reuses the environment API key** (no bespoke secret).

---

## 1. Concepts & data model

Numeric ids throughout (Messy convention — no `key`/slug columns).

- **`MetaSocialIntegration`** (`Integration` STI subclass, `kind: :social`) — a
  **Meta credential** reaching one or more Facebook Pages (+ their linked
  Instagram). Credentials in the masked JSONB `config`: `label`, `access_token`
  (System-User token), `app_secret`. The target Page / IG / ad account lives on
  the region.
- **`LinkedinSocialIntegration`** (`Integration` STI subclass, `kind: :social`) —
  a **LinkedIn credential** connected by OAuth. Masked `config`: `label`,
  `access_token`, `refresh_token`, `token_expires_at`. The target organization
  page lives on the region. See §2b for setup.
- **`social_regions`** — a market. `account_id` (+ optional `environment_id`),
  `name`, `timezone` (IANA), `post_hour` (0–23 local), `countries` (jsonb),
  `active`. Publishing targets are columns on the region: the Meta side
  (`integration_id`, `page_id`, `ig_business_account_id`, `ad_account_id`) with
  `post_to_facebook` / `post_to_instagram` toggles, and the LinkedIn side
  (`linkedin_integration_id`, `linkedin_org_id`, `linkedin_org_name`) with a
  `post_to_linkedin` toggle. A region can have a Meta target, a LinkedIn target,
  or both; one credential can serve many regions.
- **`social_posts`** — one row per `(social_region, post_date)`. `status`
  (`pending/ready/posted/failed/skipped`), `feed_alternative_id` /
  `reel_alternative_id` (FK, ON DELETE SET NULL), **`post_hour`** (nullable
  per-day override of the region default), `publish_error`.
- **`social_alternatives`** — a creative variant: `headline/body/cta_label/cta_url`,
  `source` (`generated/manual`), `has_one_attached :feed_media` (4:5) +
  `:reel_media` (9:16), each image or video (purged on destroy). `meta_*` ad
  columns are reserved for a future draft-ad feature.
- **`social_post_deliveries`** — the **posting log**, one row per publish attempt
  to one target `(post, integration, slot, channel)`: `status`, `provider_post_id`,
  `error_message`, `posted_at`. Broadcasts status changes over ActionCable
  (`social_region_<id>`, via `SocialRegionChannel`) so the log UI updates live.

---

## 2. Adding a social account (Channels) + minting the page token

Social accounts are managed in **Channels** (Integrations → add → **Meta
(Facebook & Instagram)**). Fields: label, access token, app secret, Page ID, ad
account id (optional), IG business account id (optional — auto-resolved from the
Page). The "Test" button verifies the token can reach the Page (it does **not**
post anything).

**Minting a non-expiring token (recommended):**

1. In **Meta Business Manager → Settings → Users → System Users**, create (or
   select) a **system user**.
2. Click **Generate new token**, choose your app, and select a **non-expiring**
   token.
3. Grant these permissions and generate: `pages_manage_posts`,
   `pages_read_engagement`, `pages_show_list`, `instagram_basic`,
   `instagram_content_publish`, `ads_management`, `business_management`. Copy the
   token into **Access Token**.
4. Assign the system user to the **Facebook Page** (and Ad Account) with full
   control under **Business Settings → Accounts**.
5. Get the **Page ID** (Page → About/Settings) → **Facebook Page ID** field.
6. Link the Page to its **Instagram Business/Creator account** in Meta Business
   Suite so posts can also go to Instagram. (App Secret is under App Settings →
   Basic.)

System-user tokens don't expire, so this is the durable choice over user tokens.

---

## 2b. Adding a LinkedIn account (Channels) — OAuth

LinkedIn publishes to an **Organization (company) page**, and the connecting
member must be an **administrator** of that page. Unlike Meta, no token is pasted:
the operator creates a LinkedIn credential, clicks **Connect LinkedIn**, and grants
consent. There is **one** LinkedIn app for the whole platform.

### One-time: prepare the LinkedIn app

1. At <https://www.linkedin.com/developers/apps>, create an app (or reuse one) and
   associate it with the company page that owns it.
2. Under **Products**, request the **Community Management API**. This product is
   what unlocks organization-page posting and needs LinkedIn's approval (it can
   take a few days). The lighter "Share on LinkedIn" / "Sign In with LinkedIn"
   products only allow **member** posting, not company pages, so they are not
   enough here.
3. Once approved, confirm the app has these **OAuth 2.0 scopes** available
   (requested at consent time by the backend):
   - `r_organization_social` — read the org's posts.
   - `w_organization_social` — publish posts as the org.
   - `rw_organization_admin` — list which organizations the member administers
     (populates the region's "Organization page" dropdown).
4. Under **Auth**, add the exact **redirect URL**:
   `${API_URL}/social/oauth/linkedin/callback`
   (prod `https://api.messy.sh/social/oauth/linkedin/callback`).
5. Copy the **Client ID** and **Client Secret**.

### Server env vars

Add to the `backend-env` k8s secret (namespace `messy`).
`API_URL` and `FRONTEND_URL` already exist and are reused for the redirect and the
post-consent bounce back to the Socials page.

| Var | Value |
|---|---|
| `LINKEDIN_OAUTH_CLIENT_ID` | app Client ID |
| `LINKEDIN_OAUTH_CLIENT_SECRET` | app Client Secret |

With these unset, the **Connect LinkedIn** button returns "LinkedIn OAuth is not
configured on this server" and no LinkedIn posting is attempted.

### Connect flow (operator)

1. **Channels** → add → **LinkedIn** → give it a label (this creates an empty
   `LinkedinSocialIntegration`).
2. On a region's **Edit** dialog, pick the LinkedIn credential and click **Connect
   LinkedIn**. Consent on LinkedIn, then you land back on Socials.
3. The **Organization page** dropdown now lists the pages you administer. Pick one
   and toggle **Publish to LinkedIn**.

Tokens: the access token lives ~60 days and a refresh token ~365 days. The
publisher refreshes the access token in place when it is about to lapse, so a
reconnect is only needed if the refresh token itself expires or is revoked
(the dialog has a **Reconnect** link for that).

### How posts are published

LinkedIn's Images API ingests the **image bytes** (it does not fetch by URL like
Meta), so the publisher downloads each selected render and uploads it, then creates
the post: a single image uses `content.media`, two or more use `content.multiImage`.
A **video** feed/reel slot is skipped for LinkedIn in this version (images only);
Facebook/Instagram still receive it.

---

## 3. Regions & channels (UI)

**Socials** (sidebar) lists regions. Create a region (name, timezone, default post
time, target countries, active), then open **Edit** and toggle on the Meta
accounts to link. A region with no linked, configured account shows "No account"
and won't publish. Click **Calendar** to open a region's month grid.

---

## 4. Calendar, approval rules & scheduling

- The day modal shows each alternative with 4:5 + 9:16 previews, editable copy,
  and two checkboxes — **Use as feed** / **Use as reel** (mix-and-match across
  variants). Pick a feed and/or reel, then **Mark ready**.
- **Per-day time override**: the modal's "Post time" selector overrides the
  region default for that day only (stored as `social_posts.post_hour`; blank =
  region default).
- **Manual upload**: add an image/video creative directly (feed and/or reel).
- **Post now**: publish one creative to all linked accounts immediately (not
  today-gated — for one-offs / reposts). **Publish now**: manual publish/retry of
  today's ready day.

**Scheduler** (`PublishScheduledSocialPostsJob`, `config/recurring.yml`, every 15
min): for each active, configured region, for each `ready` post dated today (region
tz), once `now.hour >= post.effective_post_hour` it enqueues `PublishSocialPostJob`.
`SocialPublisher` fans the picked slots out to the region's enabled channels:
Facebook when a Page is set, Instagram when the Page has one linked (images
auto-converted to JPEG), and LinkedIn when an organization is set (images only).
Each attempt is logged as a delivery. **Invariants:** never posts a day that isn't
today in region tz; can't ready a past/empty day, or one whose selected creative
has no imagery; idempotent (a target already `posted` is skipped;
`>=` gate is self-healing); a fully-posted day flips to `posted`, a failure to
`failed` + `publish_error`.

---

## 5. Posting log

The day modal's **Posting log** tab lists every delivery for that day (account,
channel FB/IG/LinkedIn, slot, status, provider post id, error, time) and updates live via
`SocialRegionChannel`. A failed auto-post lands here with its error; fix and use
**Publish now** to retry.

---

## 6. Provisioning a month from the API

Bulk-load a region's days with content generated elsewhere (e.g. Claude Code +
the Higgsfield MCP). Authenticated with the **environment API key** (the same one
used for the campaigns API) — `Authorization: Bearer <env api_key>`.

`POST /socials/provision`

```json
{
  "region": "Pakistan",              // region id or (case-insensitive) name
  "date": "2026-07-10",
  "replace": false,                   // true wipes prior *generated* variants (keeps manual)
  "alternatives": [
    {
      "headline": "Source factory-direct in 48h",
      "body": "Verified manufacturers, escrow-protected orders.",
      "cta_label": "Get a Quote",
      "cta_url": "https://…",
      "feed_media_url": "https://cdn/…/4x5.png",
      "reel_media_url": "https://cdn/…/9x16.mp4"
    }
  ]
}
```

The server upserts the `(region, date)` post, creates `source: generated`
alternatives, and **downloads each `*_media_url` (following redirects) and
attaches it** via Active Storage. A variant may carry only one of the two renders.
The day is **not** auto-readied — an operator still picks + readies it.

Returns `201 { success, data: { id, region, date, alternative_ids } }`. Errors:
`401` (bad/missing key), `404` (unknown region), `422` (bad date / no alternatives
/ download failure).

**curl:**
```bash
curl -sS -X POST "$MESSY_API/socials/provision" \
  -H "Authorization: Bearer $MESSY_ENV_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{ "region": "Pakistan", "date": "2026-07-10", "alternatives": [
        { "headline": "…", "cta_label": "Sign Up", "cta_url": "https://…",
          "feed_media_url": "https://…/4x5.png",
          "reel_media_url": "https://…/9x16.mp4" } ] }'
```

Workflow per concept: generate a **4:5** feed render + a **9:16** reel render, then
POST one request per day with all its alternatives (re-run with `"replace": true`
to overwrite a day you generated earlier). Keep the generation prompts somewhere
reusable: Messy stores only the rendered image, not the prompt.

---

## 7. Media serving (prod note)

Media are Active Storage attachments; URLs are built with `rails_blob_url` /
JPEG-variant representation URLs. Meta fetches media **by URL**, so in production
Active Storage must use the **S3 service** (stubbed in `config/storage.yml`) so
those URLs are publicly reachable — local Disk is dev-only. 9:16 **images** post as
portrait photos, not native Reels (true Reels need a video). IG-published media
can't be deleted via the API; removals are manual.

---

## 8. Deferred

**Draft ads.** Pushing a creative into Meta Ads Manager as a PAUSED
lead-gen ad would need a Meta Ads engine, which
Messy doesn't have. The `meta_*` columns on `social_alternatives` are reserved for
it, but the endpoint/UI are omitted in v1.
