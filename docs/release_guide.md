# BreakMate Release & Sparkle Key Management Guide

This document provides a comprehensive step-by-step guide on how to configure environment variables, generate security keys for Sparkle auto-updates, build production packages, and manage the release pipeline.

---

## 📋 Table of Contents
1. [Sparkle Key Generation (One-Time Setup)](#1-sparkle-key-generation-one-time-setup)
2. [Environment Configuration (`.env`)](#2-environment-configuration-env)
3. [Building & Releasing the App](#3-building--releasing-the-app)
4. [Troubleshooting & Key Rotation](#4-troubleshooting--key-rotation)
5. [Manual Step-by-Step Operations](#5-manual-step-by-step-operations)

---

## 1. Sparkle Key Generation (One-Time Setup)

Sparkle auto-updates are cryptographically signed using Ed25519 signatures. The client app will only install updates that match the public key embedded in its bundle.

### Automated Setup (Recommended)
Run the automated script to generate your keys and automatically patch your Xcode configuration:
```bash
./scripts/generate_sparkle_keys.sh
```

### Manual Setup
If you want to perform these steps manually:

1. **Step 1: Generate Key Pair in macOS Keychain**
   Generate a secure key pair inside your macOS Keychain system:
   ```bash
   ./macos/Pods/Sparkle/bin/generate_keys
   ```
   *Note: macOS will prompt you to authorize Keychain access. Click "Allow".*

2. **Step 2: Export Private Key to Secure File**
   Export your generated private key so the build pipeline can sign update DMGs:
   ```bash
   mkdir -p ~/secrets
   ./macos/Pods/Sparkle/bin/generate_keys -x ~/secrets/breakmate_sparkle_private.pem
   chmod 600 ~/secrets/breakmate_sparkle_private.pem
   ```

3. **Step 3: Retrieve the Public Key**
   Print the public key to embed in the app:
   ```bash
   ./macos/Pods/Sparkle/bin/generate_keys -p
   ```
   Example Output: `asdfs/asasdfasdf-sdfasd=fasdfasdf`

4. **Step 4: Update `Info.plist`**
   Add your public key to your `macos/Runner/Info.plist` file inside the `<dict>` tag:
   ```xml
   <key>SUPublicEDKey</key>
   <string>YOUR_PUBLIC_KEY_HERE</string>
   ```

---

## 2. Environment Configuration (`.env`)

The automated pipeline reads variables from a `.env` file at your project root. 

1. Copy the example configuration:
   ```bash
   cp .env.example .env
   ```
2. Edit the values inside `.env` to configure your target repositories and build options:

```bash
# Display name of the application
APP_NAME="BreakMate"

# Flutter build flavor (prod/dev)
APP_FLAVOR="prod"

# Repository where DMG releases are created
RELEASE_GITHUB_REPO=""

# Repository hosting the Sparkle update XML (appcast.xml)
APPCAST_GITHUB_REPO=""

# Target branch to push appcast.xml changes
GIT_BRANCH="main"

# Private key location (Leave empty to use Keychain auto-detection)
SPARKLE_PRIVATE_KEY=""
```

---

## 3. Building & Releasing the App

Use `./scripts/create_dmg.sh` to package, sign, and upload a new release.

### Basic Release Command
```bash
./scripts/create_dmg.sh --version 1.2.0 --build 26 --notes "Added new dark mode components."
```

### Options & Flags

| Flag | Description | Example |
|---|---|---|
| `--version` | Target release version string (Required) | `--version 1.2.0` |
| `--build` | Build integer sequence (Required) | `--build 26` |
| `--notes` | Release description string | `--notes "Bug fixes"` |
| `--notes-file` | Load release notes from a markdown file | `--notes-file release_notes.md` |
| `--skip-build` | Skip building the Flutter binary; packages the existing build output | `--skip-build` |
| `--skip-github` | Skip creating the release on GitHub; updates local files and signs DMG only | `--skip-github` |
| `--dry-run` | Verifies build configurations and outputs previews without writing files | `--dry-run` |

---

## 4. Troubleshooting & Key Rotation

### ⚠️ Error: `private-key-file already exists`
This error occurs when you run `generate_keys -x` but a file already exists at the target path (e.g. `~/secrets/breakmate_sparkle_private.pem`).
Sparkle prevents this command from running to safeguard you from accidentally overwriting your private key. 

> [!CAUTION]
> **If you overwrite your private key with a new one, all installed client versions of your app will fail to verify any future updates.** 

#### Solution A: If you want to use the existing key
Do not regenerate keys. Simply point your release scripts to the existing file:
```bash
export SPARKLE_PRIVATE_KEY="$HOME/secrets/breakmate_sparkle_private.pem"
```

#### Solution B: If you actually want to rotate/replace your keys
You must delete or move the old key out of the way before exporting the new one:
```bash
# Backup old key
mv ~/secrets/breakmate_sparkle_private.pem ~/secrets/breakmate_sparkle_private.pem.bak

# Export the new key
./macos/Pods/Sparkle/bin/generate_keys -x ~/secrets/breakmate_sparkle_private.pem
```

---

## 5. Manual Step-by-Step Operations

If you ever need to perform a release manually without running the release scripts:

### Step 1: Flutter Build
Compile the macOS release binary with your flavor:
```bash
flutter build macos --flavor prod --release
```

### Step 2: Package the DMG
Create the installer DMG package using `appdmg`:
```bash
appdmg scripts/appdmg.json release_dmg/BreakMate-Installer.dmg
```

### Step 3: Sign the DMG
Generate the Sparkle signature using the `sign_update` tool:
```bash
./macos/Pods/Sparkle/bin/sign_update --ed-key-file ~/secrets/breakmate_sparkle_private.pem release_dmg/BreakMate-Installer.dmg
```
*Take note of the returned `sparkle:edSignature` value and file `length` in bytes from the tool's console output.*

### Step 4: Publish to GitHub Releases
Create the tag and release on GitHub, then upload the DMG:
```bash
gh release create v1.2.0 \
  --repo "your-github-username/your-app-repo" \
  --title "BreakMate v1.2.0" \
  --notes "Release notes description." \
  "release_dmg/BreakMate-Installer.dmg"
```

### Step 5: Update the `appcast.xml` Feed
In your update repository, edit `appcast.xml`. Add a new `<item>` entry inside the `<channel>` block:
```xml
<item>
    <title>Version 1.2.0</title>
    <pubDate>Wed, 03 Jun 2026 12:00:00 +0000</pubDate>
    <description><![CDATA[
        <h3>BreakMate v1.2.0</h3>
        <p>Release notes description.</p>
    ]]></description>
    <enclosure url="https://github.com/your-github-username/your-app-repo/releases/download/v1.2.0/BreakMate-Installer.dmg"
               sparkle:version="26"
               sparkle:shortVersionString="1.2.0"
               sparkle:edSignature="YOUR_GENERATED_SIGNATURE_HERE"
               length="YOUR_FILE_SIZE_IN_BYTES_HERE"
               type="application/octet-stream" />
</item>
```
Commit and push the updated `appcast.xml` to publish the update.
