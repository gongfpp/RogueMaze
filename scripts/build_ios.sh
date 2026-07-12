#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "iOS export must run on macOS." >&2
  exit 2
fi
if ! command -v xcodebuild >/dev/null 2>&1; then
  echo "Xcode command-line tools are not available." >&2
  exit 2
fi
if [[ ! "${GODOT_IOS_TEAM_ID:-}" =~ ^[A-Z0-9]{10}$ ]]; then
  echo "Set GODOT_IOS_TEAM_ID to the 10-character Apple Developer Team ID." >&2
  exit 2
fi

PRESETS="$ROOT/export_presets.cfg"
BACKUP="$ROOT/.tools/export_presets.ios-backup.cfg"
mkdir -p "$ROOT/.tools" "$ROOT/builds/ios"
cp "$PRESETS" "$BACKUP"
restore_presets() {
  mv -f "$BACKUP" "$PRESETS"
  rm -f "$ROOT/assets/build/build_info.json"
}
trap restore_presets EXIT

if ! grep -q 'application/app_store_team_id=""' "$PRESETS"; then
  echo "Expected blank iOS Team ID placeholder was not found." >&2
  exit 2
fi
node "$ROOT/scripts/generate_build_info.mjs" --platform ios --configuration release
sed -i '' "s/application\/app_store_team_id=\"\"/application\/app_store_team_id=\"$GODOT_IOS_TEAM_ID\"/" "$PRESETS"

"$ROOT/scripts/test_all.sh"
IOS_LOG="$ROOT/builds/ios/export.log"
"$ROOT/scripts/run_godot.sh" --headless --path . --export-release iOS builds/ios/RogueMaze.zip 2>&1 | tee "$IOS_LOG"
if grep -Eq 'Cannot export project with preset|Project export for preset .* failed|SCRIPT ERROR|Failed to load script' "$IOS_LOG"; then
  echo "Godot reported an iOS export failure." >&2
  exit 1
fi
echo "Generated Xcode project archive: $ROOT/builds/ios/RogueMaze.zip"
