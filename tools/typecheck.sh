#!/usr/bin/env bash
# Strict type check of src/ with the luau-lsp CLI (same analyzer as the VS Code extension).
# Downloads Roblox API definitions for the pinned luau-lsp version on first run.
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="$(luau-lsp --version)"
DEFS_DIR=".luau-lsp"
DEFS="$DEFS_DIR/globalTypes.None.$VERSION.d.luau"
if [ ! -f "$DEFS" ]; then
	mkdir -p "$DEFS_DIR"
	curl -sSfL -o "$DEFS" \
		"https://raw.githubusercontent.com/JohnnyMorganz/luau-lsp/$VERSION/scripts/globalTypes.None.d.luau"
fi

rojo sourcemap --include-non-scripts -o sourcemap.json >/dev/null
luau-lsp analyze \
	--platform=roblox \
	--sourcemap=sourcemap.json \
	--definitions="$DEFS" \
	--ignore="src/server/Vendor/**" \
	--ignore="DevPackages/**" \
	src tests/specs
