# Releasing

Releases are cut from tags. Pushing a `vX.Y.Z` tag runs
[`.github/workflows/release.yml`](.github/workflows/release.yml), which builds and
publishes two `linux/amd64` images to GitHub Container Registry:

- `ghcr.io/erip-me/messy-backend:vX.Y.Z`
- `ghcr.io/erip-me/messy-frontend:vX.Y.Z`

Both are also tagged `latest`.

```sh
git tag v1.2.3
git push origin v1.2.3
```

That is the whole process. A few things worth knowing before you do it:

- **The tag must be reachable from `main`.** GitHub cannot filter tag events by branch,
  so the workflow checks it in the job and refuses to publish otherwise. Tag the commit
  you actually want shipped, not whatever a feature branch points at.
- **Published tags are immutable.** Fix a bad release by cutting the next patch tag.
  Moving or re-pushing a tag does not republish, and would leave the registry disagreeing
  with the repo.
- **Package visibility is a one-time manual step.** New GHCR packages are created private
  even when the repo is public, there is no REST API to change it, and public is a
  one-way door. Set it under the package's settings → Danger Zone → Change visibility.

Every push and pull request separately runs [`ci.yml`](.github/workflows/ci.yml): backend
tests against Postgres, frontend lint/build/unit tests, and a Docker build of both images
that is deliberately never pushed. That build exists to warm the shared buildx cache the
release job reuses, so tagging is fast and tests what was already built.
