#!/bin/bash
set -e

APP_NAME="standup"
APP_DIR="build/macos/Build/Products/Release/${APP_NAME}.app"
DMG_NAME="${APP_NAME}-Installer.dmg"
DMG_DIR="release_dmg"

# Check if build exists
if [ ! -d "$APP_DIR" ]; then
    echo "Error: Build not found at $APP_DIR. Run 'flutter build macos --release' first."
    exit 1
fi

mkdir -p "$DMG_DIR"

# 1. Deep Sign the .app bundle
echo "Deep signing .app bundle..."
codesign --force --deep --options runtime --sign "Developer ID Application: Your Name (TEAMID)" "$APP_DIR"

# 2. Create DMG
echo "Creating DMG..."
# Note: create-dmg must be installed (brew install create-dmg)
create-dmg \
  --volname "${APP_NAME} Installer" \
  --background "assets/icons/tray_icon.png" \
  --window-pos 200 120 \
  --window-size 600 400 \
  --icon-size 100 \
  --icon "${APP_NAME}.app" 150 190 \
  --hide-extension "${APP_NAME}.app" \
  --app-drop-link 450 190 \
  "${DMG_DIR}/${DMG_NAME}" \
  "$APP_DIR"

# 3. Sign the DMG
echo "Signing DMG..."
codesign --force --sign "Developer ID Application: Your Name (TEAMID)" "${DMG_DIR}/${DMG_NAME}"

echo "DMG created and signed at ${DMG_DIR}/${DMG_NAME}"
