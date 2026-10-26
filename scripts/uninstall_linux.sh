#!/usr/bin/env bash
# BreakMate Linux uninstaller (matches install_linux.sh).
#
# Usage:
#   curl -fsSL https://github.com/bijithpn/standup/releases/latest/download/uninstall_linux.sh | bash
set -euo pipefail

pkill -x breakmate 2>/dev/null || true

rm -rf "${HOME}/.local/share/breakmate"
rm -f "${HOME}/.local/bin/breakmate" \
      "${HOME}/.local/share/applications/com.bijith.breakmate.desktop" \
      "${HOME}/.local/share/icons/hicolor/512x512/apps/com.bijith.breakmate.png" \
      "${HOME}/.config/autostart/com.bijith.breakmate.desktop"
update-desktop-database "${HOME}/.local/share/applications" 2>/dev/null || true

echo "BreakMate uninstalled. User data under ~/.local/share and ~/.config was left in place."
