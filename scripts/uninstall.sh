#!/usr/bin/env bash
# BreakMate macOS uninstaller.
#
# Usage:
#   curl -fsSL https://github.com/bijithpn/standup/releases/latest/download/uninstall.sh | bash
#   ./uninstall.sh --purge     # also delete settings, history and caches
set -euo pipefail

APP_NAME="BreakMate"
BUNDLE_ID="com.bijith.breakmate"

if [ "$(uname -s)" != "Darwin" ]; then
  echo "This uninstaller is for macOS only." >&2
  exit 1
fi

osascript -e "tell application \"${APP_NAME}\" to quit" 2>/dev/null || true
sleep 1
pkill -x "${APP_NAME}" 2>/dev/null || true

rm -rf "/Applications/${APP_NAME}.app"
echo "Removed /Applications/${APP_NAME}.app"

# Launch-at-login entry, if any.
launchctl remove "$BUNDLE_ID" 2>/dev/null || true
rm -f "${HOME}/Library/LaunchAgents/${BUNDLE_ID}.plist"

if [ "${1:-}" = "--purge" ]; then
  rm -rf \
    "${HOME}/Library/Application Support/${BUNDLE_ID}" \
    "${HOME}/Library/Caches/${BUNDLE_ID}" \
    "${HOME}/Library/Preferences/${BUNDLE_ID}.plist" \
    "${HOME}/Library/Saved Application State/${BUNDLE_ID}.savedState"
  echo "Removed settings, history and caches."
else
  echo "Settings and history were kept. Re-run with --purge to delete them too."
fi

echo "${APP_NAME} uninstalled."
