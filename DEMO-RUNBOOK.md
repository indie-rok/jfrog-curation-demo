# JFrog Curation — DEMO RUNBOOK (all verified live 2026-08-18)

Instance: https://devreltest.jfrog.io · user `devrel` · trial day 6/75 (until Oct 26 2026)
Demo project: `~/jfrog-curation-demo` (all deps local, nothing global)

---

## SERVER SIDE — what I built

### Repositories
| Key | Type | Notes |
|---|---|---|
| `npm-remote` | Remote (npm) | proxy + cache of https://registry.npmjs.org |
| `npm` | Virtual (npm) | the ONE url `.npmrc` points at |

### Curation
- Service **ON**; npm package type **Connected (100%)** (incl. "CLI audit support / Pass-through")
- Fallback: **Block Always** (default)
- Group `security-team` created = waiver decision owners

### Policies (4 — all block, scope `npm-remote`, waivers manual → security-team)
| id | name | condition |
|---|---|---|
| 2 | block-malicious-packages | cond 1 · isMalicious |
| 3 | block-immature-versions-14d | cond 15 · isImmature, 14 days ← **the Axios window** |
| 4 | block-critical-cve | cond 3 · CVE CVSS ≥ 9 |
| 5 | block-copyleft-licenses | cond 10 · GNU GPL family |

**Talking point:** the 14-day immature threshold is a JFrog **built-in default** — not a number I invented.

---

## THE DEMO — 5 beats, in order

### Beat 1 — "this is a normal project" (~1 min)
    cat .npmrc          # 2 lines: registry + token. That's the whole change.
    npm install express
    → added 67 packages in 11s

### Beat 2 — the block ❌ (the money shot, ~3 min)
    npm install lodash@4.17.20

Real output:

    npm notice package lodash:4.17.20 download was blocked by jfrog packages curation
    service due to the following policies violated {block-critical-cve, CVE with CVSS
    score of 9 or above (with or without a fix version available), Package version
    contains the following vulnerability(s): CVE-2026-4800: 9.8, Upgrade to the
    following version(s): CVE-2026-4800: 4.18.0}. For details and alternatives, visit:
    https://devreltest.jfrog.io/ui/catalog/packages/details/npm/lodash/4.17.20
    npm error code E403
    npm error 403 403 Forbidden - GET .../lodash/-/lodash-4.17.20.tgz

Point at it: policy name · CVE · CVSS 9.8 · **the fix version** · a Catalog link.

### Beat 3 — the proof line (~30 s)
    ls node_modules | wc -l      # 65
    ls node_modules/lodash       # does not exist
> "The payload never reached my machine. postinstall never ran.
>  This isn't detection after the fact — nothing was downloaded."

### Beat 4 — developer empathy (~2 min)
    npx jf curation-audit

    Found 1 blocked packages for project jfrog-curation-demo:1.0.0
    ┌────┬────────┬─────────┬────────────────────┬─────────────────────┐
    │ 1  │ lodash │ 4.17.20 │ block-critical-cve │ CVE-2026-4800: 9.8  │
    │    │        │         │                    │ Upgrade to: 4.18.0  │
    └────┴────────┴─────────┴────────────────────┴─────────────────────┘
    Do you want to request a waiver for any of the listed packages? (y/n)

> "You don't discover this when CI fails at 6pm. You ask first —
>  and if you really need it, you request a waiver right here.
>  Not a black box. A conversation."

### Beat 5 — the UI, briefly (~1 min)
Curation → Audit Events = what the security team sees ("who tried to install what").
Then the Catalog link from the error message = "where the verdict comes from."

---

## ⚠️ HONEST DX FRICTION (say this — it's the developer-empathy card)
On a fresh project `jf curation-audit` fails:

    [Error] no config file was found! Before running the npm command on a project
    for the first time, the project should be configured using the 'jf npm c' command

Fix: `npx jf npm-config --repo-resolve=npm --server-id-resolve=devreltest`

> "The CLI knew exactly what was wrong and even named the command —
>  but it could have just offered to run it for me. That's a 30-second fix
>  that would remove the first-run cliff for every new developer."

---

## SETUP COMMANDS (to rebuild solo)

    # client
    mkdir ~/jfrog-curation-demo && cd ~/jfrog-curation-demo && npm init -y
    # .npmrc:
    #   registry=https://devreltest.jfrog.io/artifactory/api/npm/npm/
    #   //devreltest.jfrog.io/artifactory/api/npm/npm/:_authToken=<TOKEN>
    npm install --save-dev jfrog-cli-v2-jf          # v2.117.0, local
    npx jf c add devreltest --url=https://devreltest.jfrog.io --access-token=<TOKEN> --interactive=false
    npx jf npm-config --repo-resolve=npm --server-id-resolve=devreltest

    # token (non-expiring)
    curl -u devrel:<pass> -X POST https://devreltest.jfrog.io/artifactory/api/security/token \
      -d "username=devrel&scope=member-of-groups:*&expires_in=0"

## API cheat-sheet (endpoints that actually work here)
- Policies:    GET/POST `/xray/api/v1/curation/policies`
- Conditions:  GET `/xray/api/v1/curation/conditions` (15 predefined)
- Repos:       GET `/artifactory/api/repositories`
- Groups:      GET `/artifactory/api/security/groups`
- ⚠️ `/curation/api/v1/*` (per JFrog's ai-agent-examples doc) 404s on this instance — wrong base path.

Policy JSON that works:
```json
{"name":"block-malicious-packages","condition_id":"1","scope":"specific_repos",
 "repo_include":["npm-remote"],"policy_action":"block",
 "waiver_request_config":"manual","decision_owners":["security-team"],
 "notify_email_list":[]}
```
`waiver_request_config` ∈ {`forbidden`, `manual`}; `manual` requires `decision_owners` = existing **group**.

---

## STILL TO DO
1. **npm publish** `@indie-rok/demo-suspicious-package` — blocked: your token triggers web-auth.
   Need a **granular access token with publish permission + bypass 2FA**. → unlocks beat 5b (immature policy blocks your own 1-day-old package).
2. Screenshots for slides S4 / S10 (policy list + Audit Events).
3. JFrog MCP: enable in admin, then
   `claude mcp add --transport http --scope project jfrog https://devreltest.jfrog.io/mcp`
4. Push this project to GitHub as `indie-rok/jfrog-curation-demo`
   ⚠️ `.npmrc` contains a live token → add to `.gitignore`, commit `.npmrc.example` instead.
5. Rehearse end-to-end; **rotate all tokens after the interview.**
