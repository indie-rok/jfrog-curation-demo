# JFrog Curation Demo

Live demo environment for the talk **"Whoops, I hacked my company (all I did was `npm install`)"**.

Shows JFrog Curation blocking malicious / vulnerable / brand-new npm packages
*before* they reach a developer's machine — so `postinstall` never runs.

---

## Setup on a new computer (~5 min)

### Prerequisites
- Node.js 18+
- Access to a JFrog instance with Curation enabled

### 1. Clone

```bash
git clone https://github.com/indie-rok/jfrog-curation-demo.git
cd jfrog-curation-demo
```

### 2. Get an Artifactory access token

In the JFrog UI: avatar (top right) → **Edit Profile** → **Generate an Identity Token**.

Or via API (needs admin):

```bash
curl -u <user>:'<password>' \
  -X POST "https://<your-instance>.jfrog.io/artifactory/api/security/token" \
  -d "username=<user>&scope=member-of-groups:*&expires_in=0"
```

### 3. Create `.npmrc`

```bash
cp .npmrc.example .npmrc
chmod 600 .npmrc
```

Then edit `.npmrc` and replace `PUT_YOUR_TOKEN_HERE` with your token.

> `.npmrc` is gitignored — the token never gets committed.
> During a screen share, show `.npmrc.example`, never `.npmrc`.

### 4. Install the JFrog CLI (local to this project, not global)

```bash
npm install
```

### 5. Configure the CLI

```bash
npx jf c add devreltest \
  --url=https://devreltest.jfrog.io \
  --access-token=<YOUR_TOKEN> \
  --interactive=false --overwrite

npx jf npm-config --repo-resolve=npm --server-id-resolve=devreltest
```

> **Don't skip the second command.** Without it `jf curation-audit` fails with
> *"no config file was found"*. This is a real DX friction point — the CLI names
> the exact command you need, but doesn't offer to run it for you.

### 6. Smoke test

```bash
npm install express          # ✅ installs through Artifactory
npm install lodash@4.17.20   # ❌ 403 + policy name + CVE + upgrade path
ls node_modules/lodash       # ❌ never landed
npx jf curation-audit        # 📋 table of blocked packages + waiver prompt
```

---

## The five demo beats

| # | Command | Expected |
|---|---------|----------|
| 1 | `npm install express` | 66 packages, resolved via Artifactory |
| 2 | `npm install lodash@4.17.20` | `E403` · `block-critical-cve` · `CVE-2026-4800: 9.8` · upgrade to `4.18.0` |
| 3 | `ls node_modules/lodash` | No such file — payload never reached disk |
| 4 | `npx jf curation-audit` | Blocked-package table + waiver prompt |
| 5 | `npm install @indie_rok/demo-suspicious-package` | `E403` — *"All versions blocked - package not being found in catalog"* |

Reset between rehearsals:

```bash
rm -rf node_modules package-lock.json && npm install
```

---

## Server-side configuration

Reproduced in full in [`SETUP-GUIDE.md`](./SETUP-GUIDE.md).

**Repositories**
- `npm-remote` — Remote, npm, proxying `https://registry.npmjs.org`
- `npm` — Virtual, npm, containing `npm-remote`

**Curation**: ON · npm connected at 100% incl. CLI pass-through · fallback = Block Always

**Policies** (all `action=block`, `scope=[npm-remote]`, waiver=manual)

| Policy | Condition |
|---|---|
| `block-malicious-packages` | Flagged malicious by JFrog Security Research |
| `block-immature-versions-14d` | Version younger than 14 days |
| `block-critical-cve` | CVE with CVSS ≥ 9 |
| `block-copyleft-licenses` | Copyleft (GPL-family) license |

---

## Gotchas found while building this

1. **`missedRetrievalCachePeriodSecs` is 1800s.** Query a package through
   Artifactory before npm's CDN has propagated it, and the 404 is cached for
   30 minutes. Looks broken; isn't.
2. **`POST /artifactory/api/security/users/{name}` is a full-object replace.**
   Omitting `"admin": true` silently revokes your own admin — and returns
   `200 OK`. The UI guards against this; the API does not.
3. **JFrog's public docs reference `/curation/api/v1/`** — that 404s.
   The real path is `/xray/api/v1/curation/`.
4. **`waiver_request_config`** accepts only `forbidden` or `manual`.
5. **Waiver decision owners must be a group**, not an individual user.

---

## Files

| File | Purpose |
|---|---|
| `DEMO-RUNBOOK.md` | The five beats with timings and exact commands |
| `SETUP-GUIDE.md` | Part A: how the JFrog side was built · Part B: replication |
| `.npmrc.example` | Safe to commit and to show on screen |
| `.npmrc` | Real token — gitignored, `chmod 600` |
