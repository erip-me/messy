# Contributing to Messy

Thanks for wanting to contribute. PRs are welcome across the whole repo:
backend, frontend, website, docs.

## Before you start

- For anything larger than a small fix, open an issue first so we can agree on
  the direction before you invest time.
- Local dev setup and repo layout live in the [README](README.md).

## Ground rules

- **Backend** (`backend/`): Rails 8 API. Changes need tests
  (`bin/rails test`); the `pre-push` hook runs the full suite. After any
  migration, run `bin/rails db:schema:dump` and commit `schema.rb`,
  `queue_schema.rb`, and `cable_schema.rb` together; they must stay in sync.
- **Frontend** (`frontend/`): React + Vite. Reuse the existing shadcn/ui
  components (`src/components/ui/`) and Tailwind utilities: no new colors,
  CSS classes, or inline `style=` attributes. Verify with a clean
  `npm run build`.
- Commit messages: conventional-commit style, e.g.
  `fix(backend): reject expired tracking tokens`.

## Licensing of contributions

Messy is released under the Elastic License 2.0 (see [`LICENSE`](./LICENSE)).
Contributions are accepted under that same license (inbound = outbound). By
submitting a PR you agree that your contribution is licensed under the
Elastic License 2.0.

## Developer Certificate of Origin (DCO)

Every commit must be signed off, certifying the
[Developer Certificate of Origin](./DCO):

```sh
git commit -s
```

This adds a `Signed-off-by: Your Name <you@example.com>` trailer stating you
have the right to submit the work under the project's license. PRs with
unsigned commits can't be merged; fix up with
`git rebase --signoff origin/main`.

## Submitting

1. Fork, branch from `main`, keep the diff focused on one change.
2. Make sure the relevant checks pass locally:
   - `cd backend && bin/rails test`
   - `cd frontend && npm run build`
   - `cd website && npm run build`
3. Open the PR with a clear description of what changed and why. Screenshots
   for UI changes are appreciated.

## Reporting issues

Open an issue with clear steps to reproduce, what you expected, and what
actually happened.

## Security

Please report security vulnerabilities privately to security@messy.sh rather
than in a public issue, so we can address them before they are disclosed.
