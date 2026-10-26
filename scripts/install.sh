#!/usr/bin/env bash
# BreakMate macOS installer.
#
# Downloads the latest release DMG with curl (which does not set the macOS
# quarantine flag), copies BreakMate.app to /Applications and launches it, so
# Gatekeeper does not show "Apple could not verify BreakMate...".
#
# Usage:
#   curl -fsSL https://github.com/bijithpn/standup/releases/latest/download/install.sh | bash
#   ./install.sh [vX.Y.Z]        # optional: install a specific tag
set -euo pipefail

REPO="bijithpn/standup"
APP_NAME="BreakMate"
DMG_NAME="BreakMate-Installer.dmg"
TAG="${1:-latest}"

if [ "$(uname -s)" != "Darwin" ]; then
  echo "This installer is for macOS only." >&2
  exit 1
fi

if [ "$TAG" = "latest" ]; then
  URL="https://github.com/${REPO}/releases/latest/download/${DMG_NAME}"
else
  URL="https://github.com/${REPO}/releases/download/${TAG}/${DMG_NAME}"
fi

WORK_DIR="$(mktemp -d)"
MOUNT_POINT="${WORK_DIR}/mount"
cleanup() {
  hdiutil detach "$MOUNT_POINT" -quiet 2>/dev/null || true
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

echo "Downloading ${APP_NAME} (${TAG})..."
curl -fL --progress-bar -o "${WORK_DIR}/${DMG_NAME}" "$URL"

echo "Installing to /Applications..."
mkdir -p "$MOUNT_POINT"
hdiutil attach "${WORK_DIR}/${DMG_NAME}" -nobrowse -quiet -mountpoint "$MOUNT_POINT"

osascript -e "tell application \"${APP_NAME}\" to quit" 2>/dev/null || true
rm -rf "/Applications/${APP_NAME}.app"
cp -R "${MOUNT_POINT}/${APP_NAME}.app" /Applications/

# Safety net in case the quarantine flag was set by another tool.
xattr -cr "/Applications/${APP_NAME}.app"

echo "${APP_NAME} installed. Launching..."
open "/Applications/${APP_NAME}.app"
