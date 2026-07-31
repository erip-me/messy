# CLAUDE.md

# Messy - Multi-channel Messaging Platform

Messy is a centralized messaging service that handles email, SMS, WhatsApp, mobile push,
and template-based messaging, with campaigns, drip automation, a shared inbox, a chat
widget and social publishing. See [README.md](README.md) for the product overview.

## Repository Structure

```
messy/
├── backend/          # Rails 8.0 API (Ruby 3.3) — messages, campaigns, inbox, widget API, MCP server
│                     # (embeddable chat widget source: app/javascript/widget/)
├── frontend/         # React/TypeScript + Vite SPA (the dashboard)
├── deploy/           # Terraform for Kubernetes (modules/ + prod/ example environment)
├── docker-compose.yml# Self-host stack: Postgres + API + worker + SPA
└── bin/security-scan # Local SAST + dependency/secret/IaC scanning
```

`backend/` and `frontend/` have their own CLAUDE.md with component-specific guidance.

## Workspaces (naming)

The tenant object is called a **workspace** in the UI, a **tenant** conceptually, and
`Account` / `account_id` in the database and internal code. Only user-facing language uses
"workspace" — there is no `workspaces` table and no plan to rename the ~40 `account_id` FKs.

- One `User` row per person, with many `account_memberships` — that join table (not
  `users.account_id`) is what grants access, and `role` on it is **per workspace**.
  `users.account_id` is only the default/last-used workspace pointer; never authorize
  against it.
- A membership grants access only once `accepted_at` is set. A NULL one is an
  **invitation**: a workspace admin can name any existing address, but only that person
  turns it into access (`POST /accounts/:id/accept_invitation`). Until they do, they are
  absent from `Account#users` and nothing about them is disclosed to the workspace — so
  build lists off `member_of?` / the `accepted` scope, never off a bare membership row.
  Creating a membership in code without `accepted_at:` creates an invitation, not a
  member; that is the easy mistake here.
- `users.email` is **globally unique on purpose**: `MagicLinksController` looks users up by
  bare email, so two rows sharing one would be a silent wrong-tenant login.
- Clients pick a workspace per request with `X-Account-Id` (WebSockets: an `account_id`
  socket param). It is always re-verified against membership — a client-supplied id is a
  request, never authorization. A non-member id is a 403, never a fallback.
- In user-facing copy, "account" still means a person's **login** (e.g. "Don't have an
  account?" on the sign-in page). Don't find-replace it. The super-admin surface says
  "Tenant" and stays that way.

## Development

### Git Hooks

This repo uses a tracked `.githooks/` directory. After cloning, enable it:
```bash
git config core.hooksPath .githooks
```

- **pre-push**: Runs all backend tests. Push is blocked if any test fails.

### Backend
```bash
cd backend
bundle install
rails db:create db:migrate db:seed
rails server -p 5000
```

### Frontend
```bash
cd frontend
npm install
npm run dev
```

### Demo data

`bin/rails demo:seed` (`backend/lib/tasks/demo.rake`) seeds a fake "Lumen Labs" account
with rich data and fake provider credentials — useful for screenshots and UI work.

## Testing

Backend tests: `cd backend && bin/rails test`. The pre-push hook runs the suite.

### Backend schema dumps must stay in sync (important)

In `backend/`, the test env points the `primary`, `queue`, and `cable` connections at the
**same** `messy_test` database (`config/database.yml`), and `db/queue_schema.rb` +
`db/cable_schema.rb` are **full schema dumps** (they contain `messages`, `accounts`, etc.,
not just `solid_queue_*`/`solid_cable_*`). `db:schema:load` loads all three in sequence,
each `create_table ..., force: :cascade` dropping+recreating shared tables — so if they
drift, a later load clobbers the primary's columns.
- **Symptom:** tests pass in isolation but the full suite (and the pre-push hook) fail
  with `column X does not exist` / `unknown attribute` / NOT NULL violations.
- **Rule:** after ANY migration, run `bin/rails db:schema:dump` so all three regenerate
  together, and commit `schema.rb`, `queue_schema.rb`, and `cable_schema.rb` as a set.
  Never `git checkout` just one.
- **Reset a drifted local test DB:** `RAILS_ENV=test bin/rails db:drop db:create db:schema:load`.

### Solid Queue: recurring needs its own worker

Recurring/scheduled tasks enqueue onto the `solid_queue_recurring` queue and
`config/queue.yml` keeps a **dedicated worker** for it. Don't merge that queue into the
`default` worker: heavy catch-up jobs would starve normal job processing. Each forked
worker process needs its `queue` DB pool >= that worker's `threads`, or
`rake solid_queue:start` exits at boot.

## Sending messages (API)

Authenticate with a Bearer token (an environment's API key):

```bash
curl -s -X POST http://localhost:5000/messages \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <API_KEY>" \
  -d '{
    "type": "email",
    "to": "recipient@example.com",
    "subject": "Test subject",
    "body": "<p>Test body</p>"
  }'
```

Response `status` values: `pending` (queued for rules + delivery), `rejected` (blocked by
delivery rules), `sent`, `failed`. CC/BCC recipients are evaluated independently by
delivery rules (child messages), so some may deliver while others are rejected.

## Deployment

- **Docker Compose** (single box): `docker-compose.yml`, docs at
  [messy.sh/docs/docker-compose](https://messy.sh/docs/docker-compose)
- **Kubernetes**: Terraform modules in `deploy/modules/`, example environment in
  `deploy/prod/`, docs at [messy.sh/docs/terraform](https://messy.sh/docs/terraform).
  `terraform.tfvars`, `kubeconfig.yaml` and tfstate are gitignored — keep them that way.

## Security Scanning

Local SAST + dependency/secret/IaC scanning via [OpenGrep](https://github.com/opengrep/opengrep)
and [Trivy](https://github.com/aquasecurity/trivy). Full details in
[docs/SECURITY_SCANNING.md](docs/SECURITY_SCANNING.md).

```bash
# Install once
brew install trivy
curl -fsSL https://raw.githubusercontent.com/opengrep/opengrep/main/install.sh | bash

# Run
bin/security-scan            # everything (backend, frontend, deploy)
bin/security-scan backend    # one component
bin/security-scan --deps     # Trivy only (deps/secrets/IaC)
bin/security-scan --sast     # OpenGrep only (code patterns)
bin/security-scan --ci       # non-zero exit on HIGH/CRITICAL deps, secrets, or ERROR SAST
```
