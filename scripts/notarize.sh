#!/bin/bash
set -e

APP_NAME="standup"
DMG_PATH="release_dmg/${APP_NAME}-Installer.dmg"
KEYCHAIN_PROFILE="AC_API"

if [ ! -f "$DMG_PATH" ]; then
    echo "Error: DMG not found at $DMG_PATH"
    exit 1
fi

echo "Notarizing DMG..."
xcrun notarytool submit "$DMG_PATH" \
  --keychain-profile "$KEYCHAIN_PROFILE" \
  --wait

echo "Stapling ticket to DMG..."
xcrun stapler staple "$DMG_PATH"

echo "Notarization complete and stapled."
