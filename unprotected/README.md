# unprotected/

This folder deliberately has **no `.npmrc`**.

npm reads `.npmrc` from the current working directory — it does not walk up the
tree. So installs run from here go straight to `registry.npmjs.org`, bypassing
Artifactory and Curation entirely.

This is the "before" half of the demo: it shows what a normal developer machine
does today.

```bash
cd unprotected
npm install @indie_rok/demo-suspicious-package --foreground-scripts
```

The package's `postinstall` script executes automatically. Nothing approved it.

Then run the identical command from the parent folder — which does have an
`.npmrc` — and Curation returns a 403 before the tarball is ever downloaded.

**Do not add an `.npmrc` here.** The absence of it is the entire point.

`--foreground-scripts` is required: npm hides lifecycle script output by default,
so without it the audience sees only "added 1 package".
