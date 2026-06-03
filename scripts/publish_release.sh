#!/usr/bin/env bash
# =============================================================================
#  publish_release.sh — BreakMate Sparkle Release Publisher
# =============================================================================
#
#  WHAT THIS DOES:
#    1. Locates the Sparkle sign_update tool automatically
#    2. Signs your DMG with your Ed25519 private key
#       — Can use: macOS Keychain (automatic), or a key file you supply manually
#    3. Gets the real file size in bytes
#    4. Patches appcast.xml — updates sparkle:edSignature and length for the
#       matching version, or inserts a brand new <item> block if not found
#    5. Optionally commits and pushes to git
#
#  USAGE (standalone):
#    ./scripts/publish_release.sh \
#        --dmg /path/to/BreakMate-Installer.dmg \
#        --version 1.2.0 \
#        --build 26 \
#        --notes "What changed in this release"
#
#  KEY OPTIONS:
#    --private-key /path/to/dsa_priv.pem   Use a specific private key file
#    --account "BreakMate"                 Use a named Keychain account
#
#  OPTIONAL FLAGS:
#    --push          Commit and push appcast.xml to origin/main after patching
#    --dry-run       Print what would happen without touching any files
#
#  REQUIREMENTS:
#    - Sparkle sign_update binary (auto-detected, or set SIGN_UPDATE_PATH env var)
#    - Private key: either in macOS Keychain OR passed via --private-key
#    - python3 (ships with macOS, used for XML patching)
#
#  FIRST-TIME SETUP:
#    1. Find sign_update:
#         find ~/Library/Developer/Xcode/DerivedData -name "sign_update" | head -1
#    2. Generate your key pair (saves private key to Keychain):
#         /path/to/sign_update --generate-keys
#       OR generate and save to a file manually:
#         /path/to/sign_update --generate-keys 2>&1 | tee sparkle_keys.txt
#    3. Copy the public key → paste into macos/Runner/Info.plist as SUPublicEDKey
#    4. NEVER commit your private key to git
#
# =============================================================================

set -euo pipefail

# ── Paths ─────────────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# ── Load release config from .env ─────────────────────────────────────────────
ENV_FILE="$PROJECT_ROOT/.env"
if [[ -f "$ENV_FILE" ]]; then
  # shellcheck source=/dev/null
  set -o allexport
  source "$ENV_FILE"
  set +o allexport
else
  echo -e "\033[0;31m[ERROR]\033[0m .env not found at $ENV_FILE"
  echo "  Copy .env.example to .env and fill in your values."
  exit 1
fi

# ── Derived config (built from .env.release values) ───────────────────────────
APP_NAME="${APP_NAME:-BreakMate}"
RELEASE_GITHUB_REPO="${RELEASE_GITHUB_REPO:-bijithintersmart/standup}"
APPCAST_GITHUB_REPO="${APPCAST_GITHUB_REPO:-$RELEASE_GITHUB_REPO}"
GIT_BRANCH="${GIT_BRANCH:-main}"
APPCAST_SUBPATH="${APPCAST_SUBPATH:-appcast.xml}"

APPCAST="$PROJECT_ROOT/${APPCAST_SUBPATH}"

# ── Colour helpers ─────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

info()    { echo -e "${CYAN}[INFO]${RESET}  $*"; }
success() { echo -e "${GREEN}[OK]${RESET}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${RESET}  $*"; }
error()   { echo -e "${RED}[ERROR]${RESET} $*" >&2; exit 1; }
step()    { echo -e "\n${BOLD}▶ $*${RESET}"; }

# ── Argument parsing ───────────────────────────────────────────────────────────
DMG_PATH=""
VERSION=""
BUILD_NUMBER=""
RELEASE_NOTES=""
PRIVATE_KEY_PATH=""       # --private-key  (optional: path to .pem key file)
KEYCHAIN_ACCOUNT=""       # --account      (optional: Keychain account name)
PUSH=false
DRY_RUN=false

usage() {
  echo ""
  echo -e "${BOLD}Usage:${RESET}"
  echo "  ./scripts/publish_release.sh \\"
  echo "      --dmg /path/to/BreakMate-Installer.dmg \\"
  echo "      --version 1.2.0 \\"
  echo "      --build 26 \\"
  echo "      --notes \"What is new in this release\" \\"
  echo "      [--private-key /path/to/private_key.pem] \\"
  echo "      [--account BreakMate] \\"
  echo "      [--push] [--dry-run]"
  echo ""
  echo -e "${BOLD}Key resolution order:${RESET}"
  echo "  1. --private-key flag (explicit file path)"
  echo "  2. SPARKLE_PRIVATE_KEY env var (path to key file)"
  echo "  3. --account flag (macOS Keychain account name)"
  echo "  4. macOS Keychain (sign_update auto-detects)"
  echo ""
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dmg)           DMG_PATH="$2";          shift 2 ;;
    --version)       VERSION="$2";           shift 2 ;;
    --build)         BUILD_NUMBER="$2";      shift 2 ;;
    --notes)         RELEASE_NOTES="$2";     shift 2 ;;
    --private-key)   PRIVATE_KEY_PATH="$2";  shift 2 ;;
    --account)       KEYCHAIN_ACCOUNT="$2";  shift 2 ;;
    --push)          PUSH=true;              shift   ;;
    --dry-run)       DRY_RUN=true;           shift   ;;
    -h|--help)       usage ;;
    *) error "Unknown argument: $1. Run with --help for usage." ;;
  esac
done

# ── Validate required args ─────────────────────────────────────────────────────
[[ -z "$DMG_PATH" ]]       && error "--dmg is required."
[[ -z "$VERSION" ]]        && error "--version is required (e.g. 1.2.0)."
[[ -z "$BUILD_NUMBER" ]]   && error "--build is required (e.g. 26)."
[[ -z "$RELEASE_NOTES" ]]  && error "--notes is required."
[[ ! -f "$DMG_PATH" ]]     && error "DMG not found at: $DMG_PATH"
[[ ! -f "$APPCAST" ]]      && error "appcast.xml not found at: $APPCAST"

# Also check SPARKLE_PRIVATE_KEY env var as a key source
if [[ -z "$PRIVATE_KEY_PATH" && -n "${SPARKLE_PRIVATE_KEY:-}" ]]; then
  PRIVATE_KEY_PATH="$SPARKLE_PRIVATE_KEY"
  info "Using private key from SPARKLE_PRIVATE_KEY environment variable."
fi

if [[ -n "$PRIVATE_KEY_PATH" && ! -f "$PRIVATE_KEY_PATH" ]]; then
  error "Private key file not found at: $PRIVATE_KEY_PATH"
fi

# ── Locate sign_update ─────────────────────────────────────────────────────────
step "Locating Sparkle sign_update binary"

SIGN_UPDATE_PATH="${SIGN_UPDATE_PATH:-}"

if [[ -z "$SIGN_UPDATE_PATH" ]]; then
  SEARCH_PATHS=(
    "$PROJECT_ROOT/macos/Pods/Sparkle/bin/sign_update"   # bundled with CocoaPods Sparkle
    "$PROJECT_ROOT/macos/sign_update"
    "$PROJECT_ROOT/scripts/sign_update"
    "/usr/local/bin/sign_update"
    "/opt/homebrew/bin/sign_update"
  )

  # Search Xcode derived data (where Swift Package Manager puts it)
  while IFS= read -r -d '' found; do
    SEARCH_PATHS+=("$found")
  done < <(find ~/Library/Developer/Xcode/DerivedData -name "sign_update" -type f -print0 2>/dev/null)

  for candidate in "${SEARCH_PATHS[@]}"; do
    if [[ -x "$candidate" ]]; then
      SIGN_UPDATE_PATH="$candidate"
      break
    fi
  done
fi

if [[ -z "$SIGN_UPDATE_PATH" ]]; then
  warn "sign_update not found automatically."
  warn ""
  warn "To fix this, choose one of:"
  warn "  A) Copy sign_update to $PROJECT_ROOT/scripts/sign_update"
  warn "  B) Set: export SIGN_UPDATE_PATH=/full/path/to/sign_update"
  warn "  C) Build Sparkle via SPM in Xcode once — it will appear in DerivedData"
  warn ""
  warn "Download sign_update from:"
  warn "  https://github.com/sparkle-project/Sparkle/releases"
  error "Cannot continue without sign_update."
fi

success "Found sign_update at: $SIGN_UPDATE_PATH"

# ── Sign the DMG ───────────────────────────────────────────────────────────────
step "Signing DMG with Ed25519 key"
info "DMG path: $DMG_PATH"

# Build the sign_update command based on what key source was provided
build_sign_cmd() {
  local cmd=("$SIGN_UPDATE_PATH" "$DMG_PATH")

  if [[ -n "$PRIVATE_KEY_PATH" ]]; then
    # Use explicit key file (--private-key flag or SPARKLE_PRIVATE_KEY env)
    info "Key source: file at $PRIVATE_KEY_PATH"
    cmd+=(-f "$PRIVATE_KEY_PATH")
  elif [[ -n "$KEYCHAIN_ACCOUNT" ]]; then
    # Use a named Keychain account
    info "Key source: Keychain account '$KEYCHAIN_ACCOUNT'"
    cmd+=(--account "$KEYCHAIN_ACCOUNT")
  else
    # Default: sign_update will look up the key in the Keychain automatically
    info "Key source: macOS Keychain (auto-detect)"
  fi

  echo "${cmd[@]}"
}

if [[ "$DRY_RUN" == true ]]; then
  SIGN_CMD=$(build_sign_cmd)
  warn "[DRY-RUN] Would run: $SIGN_CMD"
  SIGNATURE="DRY_RUN_SIGNATURE_PLACEHOLDER"
  FILE_SIZE="12345678"
else
  # Run sign_update and capture output
  SIGN_CMD_ARRAY=("$SIGN_UPDATE_PATH" "$DMG_PATH")
  if [[ -n "$PRIVATE_KEY_PATH" ]]; then
    SIGN_CMD_ARRAY+=(--ed-key-file "$PRIVATE_KEY_PATH")
  elif [[ -n "$KEYCHAIN_ACCOUNT" ]]; then
    SIGN_CMD_ARRAY+=(--account "$KEYCHAIN_ACCOUNT")
  fi

  SIGN_OUTPUT=$("${SIGN_CMD_ARRAY[@]}" 2>&1) \
    || error "sign_update failed. Output:\n$SIGN_OUTPUT"

  # Parse the signature from output like: sparkle:edSignature="ABC..." length="12345"
  SIGNATURE=$(echo "$SIGN_OUTPUT" \
    | grep -oE 'sparkle:edSignature="[^"]+"' \
    | sed 's/sparkle:edSignature="//;s/"$//')

  FILE_SIZE=$(echo "$SIGN_OUTPUT" \
    | grep -oE 'length="[0-9]+"' \
    | sed 's/length="//;s/"$//')

  if [[ -z "$SIGNATURE" ]]; then
    echo ""
    error "Could not parse edSignature from sign_update output. Full output was:\n$SIGN_OUTPUT"
  fi

  # Fallback: get file size from disk if sign_update didn't output it
  [[ -z "$FILE_SIZE" ]] && FILE_SIZE=$(stat -f%z "$DMG_PATH")

  success "Signature: ${SIGNATURE:0:24}…"
  success "File size: $FILE_SIZE bytes"
fi

# ── Build release metadata ─────────────────────────────────────────────────────
PUB_DATE=$(date -u +"%a, %d %b %Y %H:%M:%S +0000")
DOWNLOAD_URL="https://github.com/${APPCAST_GITHUB_REPO}/releases/download/v${VERSION}/${APP_NAME}-Installer.dmg"

# HTML-escape the notes for CDATA safety
NOTES_HTML=$(echo "$RELEASE_NOTES" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g')

step "Release metadata"
info "Version:   $VERSION (build $BUILD_NUMBER)"
info "Date:      $PUB_DATE"
info "Download:  $DOWNLOAD_URL"
info "Notes:     ${RELEASE_NOTES:0:60}…"

# ── Patch appcast.xml using Python ────────────────────────────────────────────
step "Patching appcast.xml"

PATCH_SCRIPT=$(cat <<'PYEOF'
import sys
import re

appcast_path = sys.argv[1]
version      = sys.argv[2]
build        = sys.argv[3]
signature    = sys.argv[4]
file_size    = sys.argv[5]
download_url = sys.argv[6]
pub_date     = sys.argv[7]
notes_html   = sys.argv[8]
dry_run      = sys.argv[9] == "true"

with open(appcast_path, "r", encoding="utf-8") as f:
    content = f.read()

# ── Does this version already exist? ────────────────────────────────────────
short_ver_pattern = rf'sparkle:shortVersionString="{re.escape(version)}"'
version_exists = bool(re.search(short_ver_pattern, content))

if version_exists:
    print(f"[PATCH] Version {version} found — updating signature and length only.")

    def patch_enclosure(text, ver, sig, size):
        """
        Find the enclosure block belonging to this version and update
        sparkle:edSignature and length in place.
        """
        # First try: match the whole enclosure that has our version, replace sig+length
        pattern = (
            r'(<enclosure\b[^>]*?)'
            r'(sparkle:shortVersionString="' + re.escape(ver) + r'")'
            r'([^>]*?)'
            r'sparkle:edSignature="[^"]*"'
            r'([^>]*?)'
            r'length="[^"]*"'
            r'([^>]*?>)'
        )
        repl = (
            r'\g<1>\g<2>\g<3>'
            f'sparkle:edSignature="{sig}"'
            r'\g<4>'
            f'length="{size}"'
            r'\g<5>'
        )
        result, n = re.subn(pattern, repl, text, flags=re.DOTALL)
        if n > 0:
            return result

        # Fallback: patch each attribute independently for this version block
        result = re.sub(
            r'(sparkle:shortVersionString="' + re.escape(ver) + r'"[^>]*?)'
            r'sparkle:edSignature="[^"]*"',
            r'\g<1>' + f'sparkle:edSignature="{sig}"',
            text, flags=re.DOTALL
        )
        result = re.sub(
            r'(sparkle:shortVersionString="' + re.escape(ver) + r'"[^>]*?)'
            r'length="[^"]*"',
            r'\g<1>' + f'length="{size}"',
            result, flags=re.DOTALL
        )
        return result

    new_content = patch_enclosure(content, version, signature, file_size)

else:
    print(f"[PATCH] Version {version} not found — inserting new <item> block at top.")

    new_item = f"""\
        <item>
            <title>Version {version}</title>
            <pubDate>{pub_date}</pubDate>
            <description><![CDATA[
                <h3>BreakMate v{version}</h3>
                <p>{notes_html}</p>
                <h4>Installation Note (macOS)</h4>
                <p>Since BreakMate is not notarized by Apple, macOS may show a security warning on first launch.
                Open System Settings, go to Privacy and Security, and click Allow Anyway next to BreakMate.</p>
            ]]></description>
            <enclosure url="{download_url}"
                       sparkle:version="{build}"
                       sparkle:shortVersionString="{version}"
                       sparkle:edSignature="{signature}"
                       length="{file_size}"
                       type="application/octet-stream" />
        </item>
"""
    # Insert immediately after <language> line so it sits at the top
    m = re.search(r'<language>[^<]+</language>\s*', content)
    if m:
        pos = m.end()
        new_content = content[:pos] + new_item + content[pos:]
    else:
        print("[WARN] Could not find <language> tag — appending before </channel>.")
        new_content = content.replace("</channel>", new_item + "    </channel>")

if dry_run:
    print("[DRY-RUN] appcast.xml would become:")
    print("-" * 60)
    print(new_content[:2500])
    print("… (truncated)")
else:
    with open(appcast_path, "w", encoding="utf-8") as f:
        f.write(new_content)
    print("[OK] appcast.xml updated successfully.")
PYEOF
)

python3 - \
  "$APPCAST" \
  "$VERSION" \
  "$BUILD_NUMBER" \
  "$SIGNATURE" \
  "$FILE_SIZE" \
  "$DOWNLOAD_URL" \
  "$PUB_DATE" \
  "$NOTES_HTML" \
  "$DRY_RUN" \
  <<< "$PATCH_SCRIPT"

# ── Verify ─────────────────────────────────────────────────────────────────────
if [[ "$DRY_RUN" == false ]]; then
  if grep -q "sparkle:shortVersionString=\"$VERSION\"" "$APPCAST"; then
    success "Verified: v$VERSION entry is present in appcast.xml."
  else
    error "Verification failed — v$VERSION not found in appcast.xml after patching."
  fi

  if grep -q "DYNAMIC_SIGNATURE_WILL_BE_INSERTED_BY_CI" "$APPCAST"; then
    warn "Older entries still have a placeholder signature."
    warn "Re-run this script with the original DMGs to backfill real signatures."
  fi
fi

# ── Git commit and push ────────────────────────────────────────────────────────
if [[ "$PUSH" == true && "$DRY_RUN" == false ]]; then
  step "Committing and pushing appcast.xml"
  cd "$PROJECT_ROOT"

  if ! git diff --quiet "$APPCAST" 2>/dev/null; then
    git add "$APPCAST"
    git commit -m "chore: update appcast.xml for v${VERSION} release"
    git push origin "${GIT_BRANCH}"
    success "appcast.xml committed and pushed to ${GIT_BRANCH}."
  else
    info "appcast.xml has no changes — nothing to commit."
  fi
elif [[ "$PUSH" == true && "$DRY_RUN" == true ]]; then
  warn "[DRY-RUN] Would commit and push appcast.xml."
fi

# ── Summary ────────────────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}${BOLD}════════════════════════════════════════${RESET}"
echo -e "${GREEN}${BOLD}  appcast.xml updated for v${VERSION}${RESET}"
echo -e "${GREEN}${BOLD}════════════════════════════════════════${RESET}"
echo ""
echo -e "  Version:    ${BOLD}${VERSION}${RESET}  (build ${BUILD_NUMBER})"
echo -e "  Signature:  ${CYAN}${SIGNATURE:0:28}…${RESET}"
echo -e "  File size:  ${FILE_SIZE} bytes"
echo -e "  appcast:    ${APPCAST}"
echo ""
if [[ "$PUSH" == false ]]; then
  echo -e "${YELLOW}  To publish: git add appcast.xml && git commit -m 'chore: appcast v${VERSION}' && git push${RESET}"
fi
echo ""
