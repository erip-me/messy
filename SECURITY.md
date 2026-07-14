# Security Policy

## Reporting a vulnerability

Mail **security@messy.sh**. Do not open a public issue for security problems.

Include what you found, where (endpoint, file, or component), and steps to
reproduce. You'll get an acknowledgement within 72 hours and a status update as
we work on a fix. We ask that you give us reasonable time to ship the fix
before disclosing publicly, and we'll credit you in the release notes unless
you prefer otherwise.

## Supported versions

Messy is developed on `main` and deployed continuously; fixes land there.
Self-hosters should track `main` (or the latest release, once we cut them).

## Scope

- The application code in this repository (`backend/`, `frontend/`).
- The hosted service at messy.sh / app.messy.sh / api.messy.sh.

Out of scope: denial of service by volume, reports from automated scanners
without a demonstrated impact, and issues in third-party dependencies with no
exploitable path through Messy (report those upstream).
