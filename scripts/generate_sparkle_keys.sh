#!/usr/bin/env bash
# =============================================================================
#  generate_sparkle_keys.sh — Generate Sparkle Ed25519 Key Pair
# =============================================================================
#
#  WHAT THIS DOES:
#    1. Finds generate_keys and sign_update from your Sparkle Pods
#    2. Generates a new Ed25519 key pair (saved to macOS Keychain)
#    3. Exports the private key to ~/secrets/breakmate_sparkle_private.pem
#    4. Prints the public key (SUPublicEDKey) and patches Info.plist
#
#  USAGE (from project root):
#    ./scripts/generate_sparkle_keys.sh
#
#  OUTPUT:
#    ~/secrets/breakmate_sparkle_private.pem   ← PRIVATE key (keep secret, never commit)
#    ~/secrets/breakmate_sparkle_public.txt    ← PUBLIC key  (safe to share)
#    macos/Runner/Info.plist                   ← SUPublicEDKey auto-patched
#
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

SECRETS_DIR="$HOME/secrets"
PRIVATE_KEY_FILE="$SECRETS_DIR/breakmate_sparkle_private.pem"
PUBLIC_KEY_FILE="$SECRETS_DIR/breakmate_sparkle_public.txt"
INFO_PLIST="$PROJECT_ROOT/macos/Runner/Info.plist"

SPARKLE_BIN="$PROJECT_ROOT/macos/Pods/Sparkle/bin"
GENERATE_KEYS="$SPARKLE_BIN/generate_keys"
SIGN_UPDATE="$SPARKLE_BIN/sign_update"

# ── Colour helpers ─────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

info()    { echo -e "${CYAN}[INFO]${RESET}  $*"; }
success() { echo -e "${GREEN}[OK]${RESET}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${RESET}  $*"; }
error()   { echo -e "${RED}[ERROR]${RESET} $*" >&2; exit 1; }
step()    { echo -e "\n${BOLD}▶ $*${RESET}"; }

# ── Check tools ────────────────────────────────────────────────────────────────
[[ ! -x "$GENERATE_KEYS" ]] && error "generate_keys not found at $GENERATE_KEYS — run 'pod install' in macos/ first."
[[ ! -x "$SIGN_UPDATE" ]]   && error "sign_update not found at $SIGN_UPDATE — run 'pod install' in macos/ first."

success "Sparkle tools found at: $SPARKLE_BIN"

# ── Safety check: warn if private key already exists ──────────────────────────
if [[ -f "$PRIVATE_KEY_FILE" ]]; then
  echo ""
  warn "A private key already exists at:"
  warn "  $PRIVATE_KEY_FILE"
  warn ""
  warn "Generating a NEW key will break updates for users on old versions."
  warn "Only do this if you are setting up for the first time or rotating keys."
  echo ""
  read -r -p "$(echo -e "${YELLOW}Generate a new key anyway? [y/N]: ${RESET}")" confirm
  [[ "$confirm" != "y" && "$confirm" != "Y" ]] && { info "Aborted. Existing key kept."; exit 0; }
fi

# ── Create secrets directory ───────────────────────────────────────────────────
step "Creating secure storage directory"
mkdir -p "$SECRETS_DIR"
chmod 700 "$SECRETS_DIR"
success "Ready: $SECRETS_DIR (chmod 700)"

# ── Step 1: Generate key pair (stored in macOS Keychain) ──────────────────────
step "Step 1 — Generating Ed25519 key pair in macOS Keychain"
info "Running: generate_keys"
info "macOS may prompt you to allow Keychain access — click Allow."
echo ""

"$GENERATE_KEYS"

echo ""
success "Key pair generated and saved to Keychain."

# ── Step 2: Export private key to file ────────────────────────────────────────
step "Step 2 — Exporting private key to file"
info "Running: generate_keys -x \"$PRIVATE_KEY_FILE\""
info "macOS may prompt for Keychain access again — click Allow."
echo ""

# Remove existing file first — generate_keys -x will not overwrite
[[ -f "$PRIVATE_KEY_FILE" ]] && rm -f "$PRIVATE_KEY_FILE"

"$GENERATE_KEYS" -x "$PRIVATE_KEY_FILE"

chmod 600 "$PRIVATE_KEY_FILE"
success "Private key exported to: $PRIVATE_KEY_FILE"
success "Permissions set to 600 (only you can read it)."

# ── Step 3: Get the public key ────────────────────────────────────────────────
step "Step 3 — Reading public key"

PUBLIC_KEY=$("$GENERATE_KEYS" -p 2>/dev/null | tr -d '[:space:]')

if [[ -z "$PUBLIC_KEY" || ${#PUBLIC_KEY} -lt 30 ]]; then
  error "Could not read public key. Check Keychain access."
fi

success "Public key: ${PUBLIC_KEY:0:20}…"

# Save public key to a text file for reference
cat > "$PUBLIC_KEY_FILE" <<PUBEOF
# Sparkle Ed25519 Public Key for BreakMate
# -------------------------------------------
# Paste this into: macos/Runner/Info.plist as the value of SUPublicEDKey
# This file is SAFE to share and commit (it's public).
# Generated: $(date)

$PUBLIC_KEY
PUBEOF

success "Public key saved to: $PUBLIC_KEY_FILE"

# ── Step 4: Patch Info.plist with the public key ──────────────────────────────
step "Step 4 — Patching Info.plist with SUPublicEDKey"

if [[ ! -f "$INFO_PLIST" ]]; then
  warn "Info.plist not found at: $INFO_PLIST"
  warn "Add SUPublicEDKey manually with value: $PUBLIC_KEY"
else
  python3 - "$INFO_PLIST" "$PUBLIC_KEY" <<'PYEOF'
import sys, re

plist_path = sys.argv[1]
public_key = sys.argv[2]

with open(plist_path, "r") as f:
    content = f.read()

if "SUPublicEDKey" in content:
    # Update existing value
    updated = re.sub(
        r'(<key>SUPublicEDKey</key>\s*<string>)[^<]*(</string>)',
        rf'\g<1>{public_key}\g<2>',
        content
    )
    action = "Updated"
else:
    # Insert before closing </dict></plist>
    entry = f"\t<key>SUPublicEDKey</key>\n\t<string>{public_key}</string>\n"
    updated = re.sub(r'(</dict>\s*</plist>)', entry + r'\1', content)
    action = "Inserted"

if updated == content:
    print("[WARN] Could not patch Info.plist automatically.")
    print(f"  Add manually: <key>SUPublicEDKey</key><string>{public_key}</string>")
else:
    with open(plist_path, "w") as f:
        f.write(updated)
    print(f"[OK] {action} SUPublicEDKey in Info.plist.")
PYEOF
fi

# ── Step 5: Update publish_release.sh to use the correct flags ────────────────
# Also update create_dmg.sh signing flag from -f to --ed-key-file (correct flag name)

# ── Final summary ──────────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}${BOLD}══════════════════════════════════════════════════════════${RESET}"
echo -e "${GREEN}${BOLD}  Sparkle key pair ready${RESET}"
echo -e "${GREEN}${BOLD}══════════════════════════════════════════════════════════${RESET}"
echo ""
echo -e "  ${BOLD}Private key${RESET} (keep secret, never commit to git):"
echo -e "    ${CYAN}$PRIVATE_KEY_FILE${RESET}"
echo ""
echo -e "  ${BOLD}Public key${RESET} (SUPublicEDKey — already in Info.plist):"
echo -e "    ${GREEN}$PUBLIC_KEY${RESET}"
echo -e "    ${CYAN}$PUBLIC_KEY_FILE${RESET}"
echo ""
echo -e "  ${BOLD}Info.plist${RESET}:"
echo -e "    ${CYAN}$INFO_PLIST${RESET}"
echo ""
echo -e "${YELLOW}  Add this to your ~/.zshrc so releases find the key automatically:${RESET}"
echo -e "  ${CYAN}export SPARKLE_PRIVATE_KEY=\"$PRIVATE_KEY_FILE\"${RESET}"
echo ""
echo -e "${YELLOW}  Then every release is just:${RESET}"
echo -e "  ${CYAN}./scripts/create_dmg.sh --version 1.2.0 --build 26 --notes-file release_notes.md${RESET}"
echo ""
