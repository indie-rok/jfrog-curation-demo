# Demo environment — activate before the talk
#
#   source demo-env.sh
#
# Puts asdf shims first in PATH so this project uses the node/npm
# pinned in .tool-versions (node 22.22.2 / npm 10.9.7) instead of
# the system node.
#
# WHY npm 10: npm 12 (2026-07-08) turned install scripts OFF by
# default, and it was backported to npm 11.19.0. On those versions
# postinstall does not auto-run, which breaks the "npm install runs
# code you never approved" demonstration. npm 10.9.7 is the honest
# "what most teams are still running today" baseline.

export PATH="$HOME/.asdf/shims:$PATH"

echo "node: $(node -v)   npm: $(npm -v)"
echo
echo "  expected -> node: v22.22.2   npm: 10.9.7"
echo "  if you see v26 / 11.19.0, PATH did not take effect"
