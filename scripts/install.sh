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
  BASE_URL="https://github.com/${REPO}/releases/latest/download"
else
  BASE_URL="https://github.com/${REPO}/releases/download/${TAG}"
fi
URL="${BASE_URL}/${DMG_NAME}"

WORK_DIR="$(mktemp -d)"
MOUNT_POINT="${WORK_DIR}/mount"
cleanup() {
  hdiutil detach "$MOUNT_POINT" -quiet 2>/dev/null || true
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

echo "Downloading ${APP_NAME} (${TAG})..."
curl -fL --progress-bar -o "${WORK_DIR}/${DMG_NAME}" "$URL"

# Verify integrity. Releases older than the checksum asset have none, so skip.
if curl -fsSL -o "${WORK_DIR}/${DMG_NAME}.sha256" "${URL}.sha256" 2>/dev/null; then
  EXPECTED="$(awk '{print $1}' "${WORK_DIR}/${DMG_NAME}.sha256")"
  ACTUAL="$(shasum -a 256 "${WORK_DIR}/${DMG_NAME}" | awk '{print $1}')"
  if [ "$EXPECTED" != "$ACTUAL" ]; then
    echo "Checksum mismatch - aborting. expected=${EXPECTED} actual=${ACTUAL}" >&2
    exit 1
  fi
  echo "Checksum OK."
else
  echo "No checksum published for this release; skipping verification."
fi

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
