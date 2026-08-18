# JFrog Curation npm demo

Minimal repo for the live demo.

- Root folder = **unprotected** npm install from the public registry.
- `protected/` folder = same dependency setup, but npm points to JFrog Artifactory.
- Only `dayjs` is declared in `package.json`.
- The fake `.env` files contain exactly two safe `SUPERSAFE_` variables for the supply-chain demo.
- Install the risky packages **one by one live** so the audience sees each outcome.

## Toolchain

Use the Node version from `.tool-versions`:

```bash
node -v
npm -v
```

Expected for the lifecycle-script demo:

```text
node v22.22.2
npm 10.9.7
```

If npm is newer, the postinstall output may not appear or scripts may require approval.

## Part 1 — unprotected developer machine

From the repo root:

```bash
npm install
```

Show the normal dependency:

```bash
cat package.json
```

Point to the caret range:

```json
"dayjs": "^1.11.21"
```

### Bad package 1: known vulnerable lodash

```bash
npm install lodash@4.17.20
npm audit
```

Talk track:

> npm audit is useful, but it runs after the package is already downloaded and installed.

Optional fix demo:

```bash
npm audit fix
node -p "require('./node_modules/lodash/package.json').version"
```

### Bad package 2: suspicious supply-chain package

Install the package without pinning a version — npm will resolve the latest published version.

Show the fake secrets first:

```bash
cat .env
```

Load the fake secrets into the terminal environment:

```bash
set -a
source .env
set +a
```

Then install the package:

```bash
npm install @indie_rok/demo-suspicious-package --foreground-scripts
```

Important: `--foreground-scripts` makes npm print lifecycle-script output in the terminal.

Expected idea:

```text
SUPERSAFE_API_KEY=demo_fake_api_key_123456
SUPERSAFE_NPM_TOKEN=demo_fake_npm_token_abcdef
```

Talk track:

> These are fake secrets, safe to show. But the mechanism is real: an install script can read environment variables. In a real CI job, those could be npm tokens, GitHub tokens, cloud credentials, or deployment secrets.

Then show audit cannot detect it:

```bash
npm audit
```

Expected idea:

```text
found 0 vulnerabilities
```

## Part 2 — protected by JFrog

Important rehearsal reset: after the unprotected demo, clear npm's local cache so the protected install really has to ask JFrog.

```bash
npm cache clean --force
```

Go to the protected folder:

```bash
cd protected
```

Create the real `.npmrc` from the example:

```bash
cp .npmrc.example .npmrc
chmod 600 .npmrc
```

Edit `.npmrc` and replace `PUT_YOUR_TOKEN_HERE` with your JFrog token.

During screen share, show only:

```bash
cat .npmrc.example
```

Never show the real `.npmrc` with the token.

Install the normal dependency:

```bash
npm install
```

Expected:

```text
added 1 package
```

Now try the same bad packages:

```bash
npm install lodash@4.17.20
```

Expected:

```text
E403
block-critical-cve
CVE-2026-4800
```

Then show the same fake secrets exist here too:

```bash
cat .env
set -a
source .env
set +a
```

Then try the suspicious package again:

```bash
npm install @indie_rok/demo-suspicious-package --foreground-scripts
```

Expected:

```text
E403
All versions blocked
```

Final proof:

```bash
ls node_modules/lodash
ls node_modules/@indie_rok
```

Talk track:

> Same npm command, same fake secrets, different registry path. The package never reached my machine, so the install script never ran and the fake secrets were never printed.

## Reset between rehearsals

From either root or `protected/`:

```bash
rm -rf node_modules package-lock.json
```
