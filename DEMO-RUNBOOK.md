# DEMO RUNBOOK — JFrog Curation

**Format:** ~5 min slides → ~9 min live terminal → 1–2 min FAQ/close
**Golden rule:** one line in `.npmrc` is the whole mechanism. No CLI, no tooling.

---

## Before you start

```bash
cd ~/jfrog-curation-demo
rm -rf node_modules package-lock.json      # clean slate
clear
```

Terminal font large. `.npmrc.example` open in the editor — **never** `.npmrc`.

Re-run the whole thing once the morning of the demo (see *Timing traps* below).

---

## BEAT 1 · The change (~1 min)

```bash
cat .npmrc.example
```

> "This is the entire client-side change. One line pointing npm at Artifactory
> instead of registry.npmjs.org. No plugin, no CLI, no wrapper. Your `npm install`
> stays `npm install`."

---

## BEAT 2 · Normal work still works (~1.5 min)

```bash
npm install dayjs
```

Expected: `added 1 package in 217ms`

> "One package. Comes straight through. Same command, same speed. If curation
> made my day slower, I'd have uninstalled it by lunch."

**Then show the caret** — this sets up the whole threat model:

```bash
cat package.json
```

```json
"dependencies": {
  "dayjs": "^1.11.21"
}
```

> "See that caret? It means *this version or any newer compatible one*. I didn't
> pin 1.11.21 — npm wrote that for me, and it's the default for every package you
> install. So tomorrow, on a fresh clone with no lockfile, I get 1.11.22. Or
> 1.12.0. **I approved a version range, not a version.** That's the window
> attackers publish into."

Chosen deliberately: `dayjs` has **zero dependencies**. One line in, one package
out — nothing hides in a 67-package tree.

---

## BEAT 3 · The block (~3 min) ← **the money shot**

```bash
npm install lodash@4.17.20
```

Expected:

```
npm notice package lodash:4.17.20 download was blocked by jfrog packages
curation service due to the following policies violated {block-critical-cve,
CVE with CVSS score of 9 or above ...,CVE-2026-4800: 9.8,
Upgrade to the following version(s): CVE-2026-4800: 4.18.0}
npm error code E403
```

Talk **through** the message, slowly — it does four things:

1. names the **policy** (`block-critical-cve`)
2. names the **reason** (CVE-2026-4800, CVSS 9.8)
3. gives the **fix** (upgrade to 4.18.0)
4. links to the **catalog** entry

> "This is not 'permission denied.' It tells me which rule, why, and what to do
> instead. That's the difference between a security tool and a security wall."

---

## BEAT 4 · It never landed (~1 min)

```bash
ls node_modules/lodash
```

Expected: `No such file or directory`

> "The tarball never reached my disk. Nothing was unpacked. If there had been a
> postinstall script, it had nothing to run from. This is the whole point:
> not detection after the fact — prevention before arrival."

---

## BEAT 5 · My own package (~2 min)

```bash
npm install @indie_rok/demo-suspicious-package
```

Expected:

```
npm notice All versions blocked - package not being found in catalog
npm error code E403
```

> "I published this myself. It's real, it's on npm right now, anyone can install
> it. Artifactory won't hand it to me — JFrog's catalog has never seen it, and the
> default is deny. That's the Axios window, closed by default."

**Optional:** show `postinstall.js` in the editor, don't run it.

---

## Timing traps — read before demo day

| Trap | What happens | Fix |
|---|---|---|
| Catalog ingests my package | Beat 5 message changes from *"not found in catalog"* to the 14-day immature policy | Both are fine — **run it the morning of** so you know which line you'll get |
| Package ages past 14 days | Beat 5 may stop blocking entirely | `cd ~/demo-suspicious-package && npm version patch && npm publish` resets the clock |
| Fresh publish, queried too early | Artifactory caches the 404 for **30 min** (`missedRetrievalCachePeriodSecs: 1800`) and you get a confusing 404 instead of 403 | Publish the day *before*, never minutes before |

---

## npm 12 — know this before someone asks

**npm 12 (2026-07-08) turned install scripts OFF by default.** `allowScripts`
now defaults to off; git and remote-URL dependencies are disabled too. The change
was backported to the 11.x line — npm **11.19.0** (2026-07-29) already blocks them.

So "npm install runs code automatically" is **no longer true on current npm**.
Do not claim otherwise. If it comes up:

> "npm finally shipped this in v12 — install scripts are off by default now, and
> that's genuinely good. But: millions of CI configs and older npm versions are
> still out there, teams add allowlists to get their builds green again, and it
> does nothing about malicious code that isn't in a lifecycle script — a poisoned
> `index.js` still runs the moment you `require()` it. npm 12 narrows the window.
> Curation closes the door."

Last npm that ran postinstall by default: **11.18.0** (2026-06-29).

---

## If something breaks on stage

| Symptom | Say this | Do this |
|---|---|---|
| `E404` instead of `E403` | "cache is warming up" | Move to Beat 3 (lodash), always works |
| Network dies | "here's what it looks like" | Show slide S10 — it has the real captured output |
| lodash unexpectedly installs | "policy scope changed" | Check the policy is still `action=block` on `npm-remote` |

---

## Cut from the demo (deliberately)

**JFrog CLI (`jf curation-audit`)** — it's a *shift-left convenience*, not part of
enforcement. Blocking works with zero tooling. Keeping it in meant pasting a token
on screen, two config commands, and two cosmetic warnings.

Mention it in FAQ instead:

> "There's also `jf curation-audit`, which scans your `package.json` and shows
> everything that would be blocked *before* you install. Worth noting: on a fresh
> project it fails until you run `jf npm-config` first. The error names the exact
> command you need — it just doesn't offer to run it. Small thing, but that's the
> kind of moment where a developer gives up."

That's honest product feedback and it lands better spoken than demoed.
