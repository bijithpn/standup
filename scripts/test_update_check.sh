#!/usr/bin/env bash
# Local test for the in-app "Check for updates" flow (Sparkle).
#
# Copies the built dev app, points it at a local fake appcast, and launches it
# while streaming Sparkle logs. In the app: Settings -> Updates -> Check for
# updates (press it right after launch to exercise the startup race).
#
#   ./scripts/test_update_check.sh [--mode newer|same] [--build]
#
#   --mode newer   appcast advertises a newer version (default) -> "update available"
#   --mode same    appcast advertises the current version       -> "up to date"
#   --build        run `flutter build macos --debug --flavor dev` first
set -euo pipefail

cd "$(dirname "$0")/.."
MODE=newer
BUILD=false
PORT=8765
while [[ $# -gt 0 ]]; do
  case "$1" in
    --mode)  MODE="$2"; shift 2 ;;
    --build) BUILD=true; shift ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

SRC_APP="build/macos/Build/Products/Debug-dev/BreakMate Dev.app"
WORK="$(mktemp -d)"
trap 'kill ${SERVER_PID:-0} ${LOG_PID:-0} 2>/dev/null || true; rm -rf "$WORK"' EXIT

$BUILD && flutter build macos --debug --flavor dev -t lib/main_dev.dart
[[ -d "$SRC_APP" ]] || { echo "No dev build at $SRC_APP. Re-run with --build."; exit 1; }

cp -R "$SRC_APP" "$WORK/App.app"
PLIST="$WORK/App.app/Contents/Info.plist"
SHORT=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$PLIST")
BUILD_NO=$(/usr/libexec/PlistBuddy -c "Print CFBundleVersion" "$PLIST")
if [[ "$MODE" == newer ]]; then
  FAKE_SHORT="99.0.0"; FAKE_BUILD=9999
else
  FAKE_SHORT="$SHORT"; FAKE_BUILD="$BUILD_NO"
fi

cat > "$WORK/appcast.xml" <<XML
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel>
    <title>Local test</title>
    <item>
      <title>Version $FAKE_SHORT</title>
      <description><![CDATA[<p>Local test release notes.</p>]]></description>
      <enclosure url="http://localhost:$PORT/fake.dmg" sparkle:version="$FAKE_BUILD"
                 sparkle:shortVersionString="$FAKE_SHORT" length="0" type="application/octet-stream" />
    </item>
  </channel>
</rss>
XML

# Point the copy at the local feed and allow plain HTTP to localhost.
/usr/libexec/PlistBuddy -c "Set :SUFeedURL http://localhost:$PORT/appcast.xml" "$PLIST"
/usr/libexec/PlistBuddy -c "Add :NSAppTransportSecurity dict" "$PLIST" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Add :NSAppTransportSecurity:NSAllowsLocalNetworking bool true" "$PLIST" 2>/dev/null || true
codesign --force --deep -s - "$WORK/App.app" >/dev/null 2>&1

lsof -ti tcp:"$PORT" | xargs kill 2>/dev/null || true
(cd "$WORK" && exec python3 -m http.server "$PORT" --bind 127.0.0.1 >/dev/null 2>&1) &
SERVER_PID=$!

log stream --predicate 'process == "BreakMate Dev" AND eventMessage CONTAINS "Sparkle"' --style compact &
LOG_PID=$!

echo "App $SHORT ($BUILD_NO) -> feed advertises $FAKE_SHORT ($FAKE_BUILD) [mode: $MODE]"
echo "Launching. Press Check for updates in Settings -> Updates. Quit the app to finish."
open -W -n "$WORK/App.app"
