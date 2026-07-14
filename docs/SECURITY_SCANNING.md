# Security Scanning

Messy uses two local, self-hostable scanners — no SaaS, nothing leaves the machine/CI:

| Tool | Scans | What it catches |
|------|-------|-----------------|
| **[OpenGrep](https://github.com/opengrep/opengrep)** | Source code (SAST) | Insecure patterns — CSRF gaps, mass-assignment, XSS, hardcoded secrets, weak crypto. Open Semgrep-compatible fork. |
| **[Trivy](https://github.com/aquasecurity/trivy)** | Dependencies, secrets, IaC, SBOM, containers | Known CVEs in gems/npm, committed secrets, Terraform/Dockerfile/K8s misconfig. |

Both are driven by one wrapper script: [`bin/security-scan`](../bin/security-scan).

## Install (one-time, per machine)

```bash
# Trivy (Homebrew)
brew install trivy

# OpenGrep (official installer → ~/.local/bin/opengrep)
curl -fsSL https://raw.githubusercontent.com/opengrep/opengrep/main/install.sh | bash
```

`~/.local/bin` must be on `PATH`. Verify:

```bash
opengrep --version   # 1.22.0+
trivy --version      # 0.71.0+
```

## Run

```bash
bin/security-scan            # scan all components
bin/security-scan backend    # one component: backend | frontend | website | widget | deploy
bin/security-scan --sast     # OpenGrep only
bin/security-scan --deps     # Trivy only
bin/security-scan --ci       # exit non-zero on HIGH/CRITICAL deps, secrets, or ERROR SAST
```

JSON reports are written to `$TMPDIR/messy-security/` (e.g. `trivy-backend.json`, `opengrep-frontend.json`) for drill-down.

### What the script does

- Auto-clones the OpenGrep community ruleset into `~/.cache/messy-security/opengrep-rules` on first run (cached after that).
- Maps each component to its rule packs:
  - **backend** → Ruby + JavaScript/TypeScript + secrets (Rails app with bundled JS)
  - **frontend / website / widget** → JavaScript/TypeScript + secrets
  - **deploy** → Trivy only (Terraform IaC misconfig; no community Dart/HCL SAST rules)
- Skips tooling artifacts that carry stale lockfiles (`node_modules`, `.ruby-lsp`, `vendor/bundle`, `.terraform`, `dist`, `build`) so they don't produce false-positive CVEs.
- Filters the `jsx-not-internationalized` i18n-lint rule from the SAST summary — it's a translation-coverage check, not a security finding.

## Reading the results

**Trivy severity** is the upstream CVE rating; the script surfaces only `HIGH,CRITICAL`. Each finding lists the installed version and the fixed version — bump to (or past) the fixed version.

**OpenGrep severity:** `ERROR` = likely-exploitable, review first; `WARNING` = risky pattern, often context-dependent; `INFO` = best-practice.

Not every finding is a real vuln — triage before acting.

## Fixing findings

**Ruby gems** (`backend/`):

```bash
cd backend
bundle update <gem1> <gem2> ...      # use rbenv's Ruby (3.3.x), not system Ruby
bundle exec rspec                     # confirm no regressions
cd .. && bin/security-scan backend --deps   # re-scan
```

**npm packages** (`frontend/`):

```bash
cd <component>
npm audit fix                         # or: npm install <pkg>@<fixed-version>
npm test                              # or build, to confirm
cd .. && bin/security-scan <component> --deps
```

**Terraform / Dockerfile misconfig** (`deploy/`, `Dockerfile`): apply the remediation Trivy prints (e.g. pin image digests, drop privileged flags, set resource limits).

## Optional: block pushes / CI on findings

Add to a pre-push hook or your CI test stage:

```sh
bin/security-scan --ci --deps
```

(`--ci` exits non-zero on HIGH/CRITICAL deps, secrets, or ERROR SAST. Trivy's first run downloads its vuln DB, which is slow.)
