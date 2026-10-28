#!/bin/bash
# Build the dev flavor and launch it through LaunchServices.
#
# `flutter run` from VS Code/a terminal makes that program the app's
# "responsible process" for macOS privacy prompts. VS Code lacks the Calendar
# entitlement, so macOS silently refuses to show the Calendar prompt. Launching
# with `open` makes BreakMate its own responsible process.
set -euo pipefail
cd "$(dirname "$0")/.."
flutter build macos --debug --flavor dev -t lib/main_dev.dart
pkill -f "BreakMate Dev.app/Contents/MacOS" 2>/dev/null || true
open "build/macos/Build/Products/Debug-dev/BreakMate Dev.app"
