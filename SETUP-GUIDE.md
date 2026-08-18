# JFrog Curation Demo — Setup & Replication Guide

Two parts:
- **PART A** — what I already did on devreltest.jfrog.io (server side, persists — you only redo this if it gets wiped)
- **PART B** — how to get a *new computer* demo-ready in ~5 minutes (this is what you'll actually do)

---
---

# PART A — What I did on the JFrog website

Login: https://devreltest.jfrog.io · user `devrel`

## A1. Create the npm remote repository (the "front door")

**UI path:** top-right **Administration** → left sidebar **Repositories** → **Create a Repository** → **Remote** → **npm**

Fields:
| Field | Value |
|---|---|
| Repository Key | `npm-remote` |
| URL | `https://registry.npmjs.org` |
| Description | Proxy + cache of npmjs.org |

→ Save & Finish.

**What it is:** a proxy, not a copy. First request for a package → Artifactory fetches it from npmjs.org, caches it, serves it. This is the box in the middle of your slide-8 diagram.

## A2. Create the virtual repository (the one URL devs use)

**UI path:** same page → **Create a Repository** → **Virtual** → **npm**

| Field | Value |
|---|---|
| Repository Key | `npm` |
| Repositories | add `npm-remote` |

**Why:** devs point `.npmrc` at one URL forever. Later you can add a *local* repo (internal packages) to the same virtual repo and nobody has to change anything. Good Q&A nugget.

## A3. Turn Curation ON

**UI path:** Administration → **Curation Settings** → **General**

There's a 3-step onboarding wizard:
1. **Activate Curation application** → flip the switch → shows "Curation On" ✅
2. **Enable desired repositories** → button *Enable repositories*
3. **Protect with policies** → (done in A5)

Also on this page (left at defaults):
- Fallback behavior: **Block Always** ← important, it's the safe default
- Advanced coverage: "Enable Curation for Cached Packages" (off)

## A4. Connect the npm package type

**UI path:** Curation Settings → **Remote Repositories**

You get a table by *package type* (not per repo). Find the `npm` row → flip the switch → confirm dialog appears listing:
- Connect all current remote repositories
- Connect future remote repositories
- Notifies of manually disabled repositories
- **CLI audit support enabled (Pass-through)** ← this is what makes `jf curation-audit` work

→ click **Connect**. Donut chart goes to **Connected (100%)**.

## A5. Create a waiver-approver group

**UI path:** Administration → **User Management** → **Groups** → New Group
- Name: `security-team`
- Description: Approves curation waiver requests

**Why:** a policy with manual waivers needs *decision owners*, and those must be an existing **group** (not a username). Also just looks better on screen than "readers".

## A6. Create the 4 policies

**UI path:** Curation Settings → **Policies** → *New Policy*
For each: choose a **condition**, set scope to **specific repositories** → `npm-remote`, action **Block**, waiver requests **manual** → decision owner `security-team`.

| Policy name | Condition to pick |
|---|---|
| `block-malicious-packages` | Malicious package |
| `block-immature-versions-14d` | Package version is immature (moderate) — **14 days** |
| `block-critical-cve` | CVE with CVSS score of 9 or above (with or without a fix version available) |
| `block-copyleft-licenses` | Package license is GNU GPL |

⚠️ **Talking point:** the 14-day immature condition is a **JFrog built-in default** — you didn't invent that number. That's your Axios-window slide, backed by the vendor's own default.

## A5–A6 the fast way (API — what I actually used)

The UI is slow; the REST API is instant and reproducible. Auth = your admin user/password.

```bash
JF_URL="https://devreltest.jfrog.io"
JF_USER="devrel"
JF_PASS="<password>"

# --- remote repo ---
curl -u "$JF_USER:$JF_PASS" -X PUT "$JF_URL/artifactory/api/repositories/npm-remote" \
  -H "Content-Type: application/json" -d '{
    "key":"npm-remote","rclass":"remote","packageType":"npm",
    "url":"https://registry.npmjs.org","repoLayoutRef":"npm-default"}'

# --- virtual repo ---
curl -u "$JF_USER:$JF_PASS" -X PUT "$JF_URL/artifactory/api/repositories/npm" \
  -H "Content-Type: application/json" -d '{
    "key":"npm","rclass":"virtual","packageType":"npm",
    "repositories":["npm-remote"]}'

# --- group ---
curl -u "$JF_USER:$JF_PASS" -X PUT "$JF_URL/artifactory/api/security/groups/security-team" \
  -H "Content-Type: application/json" \
  -d '{"name":"security-team","description":"Approves curation waiver requests"}'

# --- see available conditions (15 predefined) ---
curl -u "$JF_USER:$JF_PASS" "$JF_URL/xray/api/v1/curation/conditions"

# --- policies (condition ids: 1=malicious, 15=immature14d, 3=CVSS>=9, 10=GPL) ---
for spec in "block-malicious-packages:1" "block-immature-versions-14d:15" \
            "block-critical-cve:3" "block-copyleft-licenses:10"; do
  name="${spec%%:*}"; cond="${spec##*:}"
  curl -u "$JF_USER:$JF_PASS" -X POST "$JF_URL/xray/api/v1/curation/policies" \
    -H "Content-Type: application/json" -d "{
      \"name\":\"$name\",\"condition_id\":\"$cond\",\"scope\":\"specific_repos\",
      \"repo_include\":[\"npm-remote\"],\"policy_action\":\"block\",
      \"waiver_request_config\":\"manual\",\"decision_owners\":[\"security-team\"],
      \"notify_email_list\":[]}"
done
```

⚠️ **Curation ON (A3) and package-type connect (A4) must be done in the UI** — the API 404s until the service is activated.

**Gotchas I hit (so you don't):**
- `waiver_request_config` only accepts `forbidden` or `manual`. Not "allowed".
- `manual` requires `decision_owners`, and it must be an existing **group**.
- The `/curation/api/v1/*` base path in JFrog's public ai-agent-examples doc **404s** on this instance. The real one is `/xray/api/v1/curation/*`.

---
---

# PART B — Replicate on a NEW computer (~5 min)

Nothing above needs redoing — the server config persists. This is client-side only.

## B0. Prerequisites
- Node + npm installed
- Nothing else. No global installs.

## B1. Get an Artifactory token

Two ways:

**UI:** top-right avatar → **Edit Profile** → **Generate an Identity Token** → copy it.

**CLI (what I used, non-expiring):**
```bash
curl -u devrel:'<password>' -X POST \
  "https://devreltest.jfrog.io/artifactory/api/security/token" \
  -d "username=devrel&scope=member-of-groups:*&expires_in=0"
```
Copy the `access_token` value.

## B2. Create the project

```bash
mkdir ~/jfrog-curation-demo && cd ~/jfrog-curation-demo
npm init -y
```

## B3. The `.npmrc` — this is the whole "integration"

```bash
cat > .npmrc <<EOF
registry=https://devreltest.jfrog.io/artifactory/api/npm/npm/
//devreltest.jfrog.io/artifactory/api/npm/npm/:_authToken=<YOUR_TOKEN>
EOF
chmod 600 .npmrc
```

☝️ **This is your FAQ slide made real.** Two lines. `npm install` is unchanged.
Note the URL pattern: `/artifactory/api/npm/<virtual-repo-name>/`.

## B4. Install the JFrog CLI **locally** (not global)

```bash
npm install --save-dev jfrog-cli-v2-jf
npx jf --version           # 2.117.0
```

## B5. Configure the CLI

```bash
npx jf c add devreltest \
  --url=https://devreltest.jfrog.io \
  --access-token=<YOUR_TOKEN> \
  --interactive=false --overwrite

npx jf npm-config --repo-resolve=npm --server-id-resolve=devreltest
```

⚠️ **Don't skip the second command.** Without it `jf curation-audit` fails with:
`[Error] no config file was found! ... configure using the 'jf npm c' command`
(That failure is itself great talk material — see below.)

## B6. Smoke-test before you present

```bash
npm install express                 # ✅ added ~67 packages
npm install lodash@4.17.20          # ❌ E403 blocked, with reason
ls node_modules/lodash              # ❌ doesn't exist = payload never landed
```

If both behave as above, you're demo-ready.

## B7. Reset between rehearsals

```bash
rm -rf node_modules package-lock.json
npm install express
```

---

# THE DEMO — 5 beats

### Beat 1 · "a totally normal project" (~1 min)
```bash
cat .npmrc
npm install express
```
> "Two lines of config. Same command. Same speed."

### Beat 2 · the block ❌ (~3 min — the money shot)
```bash
npm install lodash@4.17.20
```
```
npm notice package lodash:4.17.20 download was blocked by jfrog packages curation
service due to the following policies violated {block-critical-cve, CVE with CVSS
score of 9 or above (with or without a fix version available), Package version
contains the following vulnerability(s): CVE-2026-4800: 9.8, Upgrade to the
following version(s): CVE-2026-4800: 4.18.0}. For details and alternatives, visit:
https://devreltest.jfrog.io/ui/catalog/packages/details/npm/lodash/4.17.20
npm error code E403
```
Point at each part: **policy name · CVE · CVSS 9.8 · the fix version · a Catalog link.**

### Beat 3 · the proof (~30 s)
```bash
ls node_modules | wc -l        # 65
ls node_modules/lodash         # No such file or directory
```
> "The payload never reached my machine. postinstall never ran.
>  This isn't detection after the fact — nothing was ever downloaded."

### Beat 4 · developer empathy (~2 min)
```bash
npx jf curation-audit
```
Prints a table of blocked packages, then asks:
`Do you want to request a waiver for any of the listed packages? (y/n)`
> "You don't find out when CI fails at 6pm. You ask first. And if you really need
>  the package, you request a waiver right here. Not a black box — a conversation."

### Beat 5 · the UI (~1 min)
Curation → **Audit Events** = what the security team sees ("who tried to install what").
Then follow the Catalog link from the error = "where the verdict comes from."

---

# The honest-friction card (use it — it's your best DevRel moment)

On a fresh machine, `jf curation-audit` fails until you run `jf npm-config`. Say it out loud:

> "Setting this up, I hit a wall: the audit command failed on a fresh project.
>  The CLI knew exactly what was wrong and even named the command I needed —
>  but it could have just offered to run it for me. That's a 30-second fix that
>  removes the first-run cliff for every new developer."

That's product understanding + developer empathy + a concrete roadmap suggestion in three sentences.

---

# Security checklist ⚠️
- `.npmrc` holds a live token → **`.gitignore` it**; commit `.npmrc.example` instead.
- Rotate the Artifactory token *and* the npm token after the interview.
- Never paste tokens into slides or screen-share `cat .npmrc` with a real token visible
  → for the demo, either use `.npmrc.example` on screen or blur/scroll past it.
