#!/usr/bin/env sh
set -eu

PROJECT_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
RUNS=${1:-250}
case "$RUNS" in
  ''|*[!0-9]*)
    printf 'Runs must be an integer from 1 to 5000.\n' >&2
    exit 2
    ;;
esac
if [ "$RUNS" -lt 1 ] || [ "$RUNS" -gt 5000 ]; then
  printf 'Runs must be an integer from 1 to 5000.\n' >&2
  exit 2
fi

cd "$PROJECT_ROOT"
OUTPUT=$("$PROJECT_ROOT/scripts/run_godot.sh" --headless --path . --script tests/godot/soak_runner.gd -- "--runs=$RUNS" 2>&1) || {
  printf '%s\n' "$OUTPUT"
  exit 1
}
printf '%s\n' "$OUTPUT"
if printf '%s\n' "$OUTPUT" | grep -Eq 'SCRIPT ERROR|Failed to load script'; then
  exit 1
fi
printf '%s\n' "$OUTPUT" | grep -Eq "Godot soak: $RUNS expedition\(s\), [0-9]+ invariant check\(s\), all passed"
