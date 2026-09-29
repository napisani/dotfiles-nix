#!/bin/sh
set -eu
here=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
packages=${PI_PACKAGE_DIR:-$HOME/.pi/agent/npm}/node_modules
if [ ! -d "$packages" ]; then
  echo "Pi package dependencies not found: $packages" >&2
  exit 1
fi
if [ -e "$here/node_modules" ] || [ -L "$here/node_modules" ]; then
  echo "Refusing to replace existing $here/node_modules" >&2
  exit 1
fi
ln -s "$packages" "$here/node_modules"
trap 'rm "$here/node_modules"' EXIT
cd "$here"
tsc --noEmit --strict --noUnusedLocals --skipLibCheck --module nodenext --moduleResolution nodenext --target es2022 --allowImportingTsExtensions --types node index.ts
bun test index.test.ts
