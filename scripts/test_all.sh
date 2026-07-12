#!/usr/bin/env sh
set -eu

PROJECT_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$PROJECT_ROOT"
npm test
IMPORT_OUTPUT=$("$PROJECT_ROOT/scripts/run_godot.sh" --headless --editor --path . --quit 2>&1) || {
  printf '%s\n' "$IMPORT_OUTPUT"
  exit 1
}
printf '%s\n' "$IMPORT_OUTPUT"
if printf '%s\n' "$IMPORT_OUTPUT" | grep -Eq 'SCRIPT ERROR|Failed to load script'; then
  exit 1
fi

TEST_OUTPUT=$("$PROJECT_ROOT/scripts/run_godot.sh" --headless --path . --script tests/godot/test_runner.gd 2>&1) || {
  printf '%s\n' "$TEST_OUTPUT"
  exit 1
}
printf '%s\n' "$TEST_OUTPUT"
if printf '%s\n' "$TEST_OUTPUT" | grep -Eq 'SCRIPT ERROR|Failed to load script'; then
  exit 1
fi
printf '%s\n' "$TEST_OUTPUT" | grep -Eq 'Godot rules: [0-9]+ assertion\(s\), all passed'
