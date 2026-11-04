#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LUAU_BIN="/opt/homebrew/bin/luau"

if [[ ! -x "$LUAU_BIN" ]]; then
	echo "Error: luau binary not found at $LUAU_BIN" >&2
	exit 1
fi

ARGS=()

for file in "$ROOT_DIR"/src/modules/Config/*.lua; do
	name="$(basename "$file" .lua)"
	ARGS+=("Config.$name" "$(cat "$file")")
done

for file in "$ROOT_DIR"/src/serverstorage/Modules/Config/*.lua; do
	name="$(basename "$file" .lua)"
	ARGS+=("ServerConfig.$name" "$(cat "$file")")
done

for name in ConfigLookup Hitbox; do
	file="$ROOT_DIR/src/modules/Shared/$name.lua"
	ARGS+=("Shared.$name" "$(cat "$file")")
done

"$LUAU_BIN" "$ROOT_DIR/tools/tests/suite.lua" -a "${ARGS[@]}"
python3 "$ROOT_DIR/tools/tests/run_rooms.py"
