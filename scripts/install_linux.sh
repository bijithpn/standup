#!/usr/bin/env bash
# BreakMate Linux installer (per-user, no root needed).
#
# Usage:
#   curl -fsSL https://github.com/bijithpn/standup/releases/latest/download/install_linux.sh | bash
#   ./install_linux.sh [vX.Y.Z]        # optional: install a specific tag
set -euo pipefail

REPO="bijithpn/standup"
TAG="${1:-latest}"

if [ "$(uname -s)" != "Linux" ]; then
  echo "This installer is for Linux only." >&2
  exit 1
fi

API="https://api.github.com/repos/${REPO}/releases"
if [ "$TAG" = "latest" ]; then API="${API}/latest"; else API="${API}/tags/${TAG}"; fi

URL="$(curl -fsSL "$API" | grep -oE '"browser_download_url": *"[^"]*linux-x64\.tar\.gz"' | head -1 | cut -d'"' -f4)"
if [ -z "$URL" ]; then
  echo "No Linux archive found for release '${TAG}'." >&2
  exit 1
fi

WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT

echo "Downloading ${URL##*/}..."
curl -fL --progress-bar -o "${WORK_DIR}/breakmate.tar.gz" "$URL"
tar -xzf "${WORK_DIR}/breakmate.tar.gz" -C "$WORK_DIR"
SRC="$(find "$WORK_DIR" -maxdepth 1 -type d -name 'BreakMate-*-linux-x64' | head -1)"

INSTALL_DIR="${HOME}/.local/share/breakmate"
BIN_DIR="${HOME}/.local/bin"
APPS_DIR="${HOME}/.local/share/applications"
ICON_DIR="${HOME}/.local/share/icons/hicolor/512x512/apps"

rm -rf "$INSTALL_DIR"
mkdir -p "$INSTALL_DIR" "$BIN_DIR" "$APPS_DIR" "$ICON_DIR"
cp -r "$SRC"/. "$INSTALL_DIR"/
ln -sf "${INSTALL_DIR}/breakmate" "${BIN_DIR}/breakmate"
cp "${SRC}/com.bijith.breakmate.png" "${ICON_DIR}/com.bijith.breakmate.png"
sed "s|^Exec=.*|Exec=${INSTALL_DIR}/breakmate %u|" \
  "${SRC}/com.bijith.breakmate.desktop" > "${APPS_DIR}/com.bijith.breakmate.desktop"
update-desktop-database "$APPS_DIR" 2>/dev/null || true

echo "BreakMate installed to ${INSTALL_DIR}. Launch it from your app menu or run 'breakmate'."
case ":$PATH:" in *":${BIN_DIR}:"*) ;; *) echo "Note: add ${BIN_DIR} to your PATH to run 'breakmate' from a terminal." ;; esac
