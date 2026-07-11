#!/usr/bin/env sh
set -eu

PROJECT_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$PROJECT_ROOT"
npm test
"$PROJECT_ROOT/scripts/run_godot.sh" --headless --editor --path . --quit
"$PROJECT_ROOT/scripts/run_godot.sh" --headless --path . --script tests/godot/test_runner.gd
