#!/usr/bin/env sh
set -eu

PROJECT_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
GODOT_BIN=${GODOT_BIN:-godot}

export XDG_DATA_HOME="$PROJECT_ROOT/.tools/user-data/xdg-data"
export XDG_CONFIG_HOME="$PROJECT_ROOT/.tools/user-data/xdg-config"
export XDG_CACHE_HOME="$PROJECT_ROOT/.tools/user-data/xdg-cache"
mkdir -p "$XDG_DATA_HOME" "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME"

exec "$GODOT_BIN" "$@"
